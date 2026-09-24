import 'dart:async';

import 'package:cobalt/src/bootstrap/cobalt_scope_builder.dart';
import 'package:cobalt/src/decorator/cobalt_decorator.dart';
import 'package:cobalt/src/errors/cobalt_decorator_error.dart';
import 'package:cobalt/src/errors/cobalt_depends_on_error.dart';
import 'package:cobalt/src/errors/cobalt_dispose_error.dart';
import 'package:cobalt/src/errors/cobalt_dispose_failure.dart';
import 'package:cobalt/src/errors/cobalt_dispose_stage.dart';
import 'package:cobalt/src/errors/cobalt_duplicate_registration_error.dart';
import 'package:cobalt/src/errors/cobalt_lazy_async_error.dart';
import 'package:cobalt/src/errors/cobalt_not_parameterized_error.dart';
import 'package:cobalt/src/errors/cobalt_not_ready_error.dart';
import 'package:cobalt/src/errors/cobalt_param_required_error.dart';
import 'package:cobalt/src/errors/cobalt_param_type_error.dart';
import 'package:cobalt/src/errors/cobalt_not_registered_error.dart';
import 'package:cobalt/src/errors/cobalt_override_error.dart';
import 'package:cobalt/src/errors/cobalt_scope_state_error.dart';
import 'package:cobalt/src/factory/cobalt_async_factory.dart';
import 'package:cobalt/src/factory/cobalt_factory.dart';
import 'package:cobalt/src/factory/cobalt_param_factory.dart';
import 'package:cobalt/src/graph/topological_sort.dart';
import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/lifecycle/cobalt_injectable.dart';
import 'package:cobalt/src/lifecycle/cobalt_resolver.dart';
import 'package:cobalt/src/lifecycle/async_disposable.dart';
import 'package:cobalt/src/lifecycle/disposable.dart';
import 'package:cobalt/src/observer/cobalt_observer.dart';
import 'package:cobalt/src/observer/cobalt_scope_ref.dart';
import 'package:cobalt/src/overrides/cobalt_override.dart';
import 'package:cobalt/src/registration/cobalt_registration.dart';
import 'package:cobalt/src/scope/cobalt_registration_kind.dart';
import 'package:cobalt/src/scope/cobalt_scope_state.dart';
import 'package:cobalt/src/scope/resolution_tracker.dart';

/// A container of registrations with a lifetime of its own.
///
/// Scopes form a tree. A child sees everything its ancestors registered and
/// can shadow any of it; resolution never walks downwards. Disposing a scope
/// disposes its children first, then its own instances in reverse creation
/// order, so nothing is torn down before what depends on it.
///
/// A parent holds its children strongly, which is what makes that ordering
/// guaranteed. The flip side is an explicit ownership contract: whoever
/// creates a scope closes it. A scope dropped without [dispose] leaks, by
/// design — the alternative is a teardown that may silently never run.
///
/// ```dart
/// final app = CobaltScope.root(name: 'app')
///   ..registerLazySingleton<Logger>(const LoggerFactory());
/// await app.init();
///
/// final session = app.push('session');
/// // ... use it ...
/// await session.dispose();
/// ```
final class CobaltScope implements CobaltResolver {
  CobaltScope._(this.name, this.parent, this._tracker, this._observers)
    : depth = parent == null ? 0 : parent.depth + 1;

  /// Creates a detached root scope.
  ///
  /// [name] appears in error messages and when inspecting the tree. The
  /// caller owns the result and must [dispose] it.
  ///
  /// [observers] watch this scope and every scope pushed from it.
  ///
  /// [overrides] are registered first, and the real registration of each of
  /// their keys is then skipped rather than rejected as a duplicate. See
  /// [CobaltOverride].
  factory CobaltScope.root({
    String name = 'root',
    List<CobaltObserver> observers = const [],
    List<CobaltOverride<Object>> overrides = const [],
  }) {
    _assertOverridesAreSound(overrides, name);
    return CobaltScope._(
      name,
      null,
      CobaltResolutionTracker(),
      List.unmodifiable(observers),
    ).._applyOverrides(overrides);
  }

  /// This scope's name, used in diagnostics.
  final String name;

  /// The scope this one was pushed from, or `null` for a root.
  final CobaltScope? parent;

  /// How far below the root this scope sits. `0` for a root.
  final int depth;

  final _children = <CobaltScope>[];
  final _registrations = <CobaltKey, CobaltRegistration>{};
  final _owned = <_OwnedInstance>[];
  final CobaltResolutionTracker _tracker;
  final List<CobaltObserver> _observers;

  Future<void>? _initFuture;
  CobaltScopeState _state = CobaltScopeState.open;
  int _order = 0;

  final _lazyBuilding = <LazyAsyncSingletonRegistration>{};
  var _closing = false;

  final _overriddenKeys = <CobaltKey>{};
  final _claimed = <CobaltKey>{};
  var _applyingOverrides = false;

  final _decorators = <CobaltKey, List<_Decoration>>{};
  final _decorated = <CobaltKey, Object>{};
  final _served = <CobaltKey>{};

  /// Where this scope is in its lifecycle.
  CobaltScopeState get state => _state;

  /// The child scopes currently alive, in the order they were pushed.
  List<CobaltScope> get children => List.unmodifiable(_children);

  /// The outermost scope above this one, or this scope when it is the root.
  CobaltScope get root {
    var current = this;
    for (var parent = current.parent; parent != null; parent = current.parent) {
      current = parent;
    }
    return current;
  }

  /// What this scope registers, in registration order.
  ///
  /// This is what was *declared*, not what exists. A lazy singleton nobody
  /// resolved is indistinguishable here from one that is built, and an async
  /// singleton appears whether or not `init()` has reached it.
  ///
  /// Three more things it deliberately is not. Objects handed to [adopt] have
  /// no key at all, so this is not what teardown will release. One key can
  /// stand for any number of live transients, or none. And nothing records
  /// what a factory will ask for, so this is a list, never a graph.
  ///
  /// Empty after [dispose], which clears the registrations rather than keeping
  /// a tombstone.
  Set<CobaltKey> get keys => Set.unmodifiable(_registrations.keys);

  /// The keys this scope registers from an override rather than from its own
  /// registrations.
  ///
  /// Whether the real registration has been skipped yet is not part of the
  /// answer: an override is in force from the moment the scope exists.
  Set<CobaltKey> get overriddenKeys => Set.unmodifiable(_overriddenKeys);

  /// Every key resolvable from here, mapped to the scope that owns it.
  ///
  /// Nearest wins: a key this scope registers shadows the same key in an
  /// ancestor, exactly as [get] resolves it.
  ///
  /// The owner is the point of the map. A factory is called with the scope
  /// that owns *its* registration, not the scope you asked from, so a key
  /// alone cannot tell you what an override will actually affect.
  Map<CobaltKey, CobaltScope> get visibleKeys {
    final result = <CobaltKey, CobaltScope>{};
    for (CobaltScope? scope = this; scope != null; scope = scope.parent) {
      for (final key in scope._registrations.keys) {
        result.putIfAbsent(key, () => scope!);
      }
    }
    return Map.unmodifiable(result);
  }

  /// What kind of registration [key] has, or null when nothing registers it.
  ///
  /// Resolves through ancestors like [get] does, so it answers for the scope
  /// the key would actually come from.
  ///
  /// For tools. It exists because the alternative — telling a parameterized
  /// registration apart from a broken one by reading an exception message — is
  /// parsing prose.
  CobaltRegistrationKind? debugKindOf(CobaltKey key) =>
      switch (_lookup(key)?.registration) {
        SingletonRegistration() => CobaltRegistrationKind.singleton,
        LazySingletonRegistration() => CobaltRegistrationKind.lazySingleton,
        TransientRegistration() => CobaltRegistrationKind.transient,
        AsyncSingletonRegistration() => CobaltRegistrationKind.asyncSingleton,
        LazyAsyncSingletonRegistration() =>
          CobaltRegistrationKind.lazyAsyncSingleton,
        ParamRegistration() => CobaltRegistrationKind.parameterized,
        null => null,
      };

  /// The decorators that wrap [key], in the order they apply, innermost
  /// first; empty when none do.
  ///
  /// Answered for the scope that owns [key], the only one whose decorators
  /// can apply to it.
  List<Type> debugDecoratorsOf(CobaltKey key) => [
    for (final decoration
        in _lookup(key)?.scope._decorators[key] ?? const <_Decoration>[])
      decoration.type,
  ];

  /// Resolves [key] without naming its type, or null when nothing registers it.
  ///
  /// The typed [get] cannot be called from a loop over [keys]: Dart has no way
  /// to turn a `Type` back into a type argument. This is the same resolution,
  /// reached by value instead — which is what lets a tool walk a whole graph.
  ///
  /// Everything [get] throws, this throws: an async singleton before `init()`
  /// raises `CobaltNotReadyError`, a parameterized registration raises
  /// `CobaltError`, a cycle raises `CobaltCycleError`. Check [debugKindOf] first
  /// rather than reading those apart afterwards.
  Object? debugResolve(CobaltKey key) {
    _assertUsable();
    final found = _lookup(key);
    if (found == null) return null;
    return found.scope._materialize(found.registration);
  }

  /// [debugResolve] by way of [getAsync]: builds a lazy async registration
  /// that is not built yet, and waits for an `init()` still in progress.
  Future<Object?> debugResolveAsync(CobaltKey key) async {
    _assertUsable();
    final found = _lookup(key);
    if (found == null) return null;
    return found.scope._resolveAsync(found.registration);
  }

  /// Resolves a parameterized [key] with [param], without naming its types.
  ///
  /// The key-based twin of [getWithParam], for the same reason [debugResolve]
  /// is the twin of [get]: a walk over [keys] has no type arguments to give.
  ///
  /// Returns null when nothing registers [key]. Throws `CobaltError` when the
  /// registration is not parameterized, and `CobaltParamTypeError` when [param]
  /// is not what its factory takes.
  Object? debugResolveWithParam(CobaltKey key, Object param) {
    _assertUsable();
    final found = _lookup(key);
    if (found == null) return null;
    final registration = found.registration;
    if (registration is! ParamRegistration) {
      throw CobaltNotParameterizedError(key);
    }
    if (!registration.accepts(param)) {
      throw CobaltParamTypeError(
        key,
        registration.paramType,
        param.runtimeType,
      );
    }
    return found.scope._tracker.guard(key, () {
      final instance = registration.factory.create(found.scope, param);
      found.scope._afterCreate(
        instance,
        key,
        kind: CobaltRegistrationKind.parameterized,
        retain: false,
      );
      return found.scope._serveFresh(key, instance);
    });
  }

  /// Renders this scope and everything under it, one line per scope.
  ///
  /// For diagnostics and test failures. The shape is not a contract.
  String debugDescribeTree() => _describe(0).join('\n');

  List<String> _describe(int indent) => [
    '${'  ' * indent}$name  [${_state.name}]  ${_registrations.length} '
        'registration(s)',
    for (final child in _children) ...child._describe(indent + 1),
  ];

  /// Whether the scope still accepts registrations and resolutions.
  ///
  /// False once teardown has begun, which is what turns later use into an
  /// `CobaltScopeStateError` instead of work against half-cleared state.
  bool get isUsable =>
      _state == CobaltScopeState.open ||
      _state == CobaltScopeState.initializing ||
      _state == CobaltScopeState.active;

  /// Creates a child scope that resolves through this one.
  ///
  /// [observers] are added to the ones inherited from here, and watch this
  /// child and its descendants only — the first thing they see is this scope
  /// being pushed. Without it the list is fixed when the root is built, so
  /// anything that wants to watch one subtree has to be installed at startup
  /// and filter afterwards.
  ///
  /// The child is retained until it is disposed, either directly or as part of
  /// disposing this scope. Use it for anything with a shorter life than the
  /// parent — a session, a screen, a request — and to override a dependency
  /// without touching the parent.
  ///
  /// [overrides] replace registrations the child makes itself, as they do for
  /// [CobaltScope.root]. They cannot reach a key an ancestor owns: its
  /// factories keep resolving from where they are registered.
  CobaltScope push(
    String childName, {
    List<CobaltObserver> observers = const [],
    List<CobaltOverride<Object>> overrides = const [],
  }) {
    _assertUsable();
    _assertOverridesAreSound(overrides, childName);
    final child = CobaltScope._(childName, this, _tracker, [
      ..._observers,
      ...observers,
    ]);
    _children.add(child);
    child._notify((observer) => observer.onScopePushed(child.ref));
    child._applyOverrides(overrides);
    return child;
  }

  /// Refuses a list of overrides before any scope exists to hold it.
  ///
  /// Checked up front rather than while applying, because a failure halfway
  /// would leave a pushed child in the tree with half its overrides registered
  /// — and a root nobody holds, owning values nobody will close.
  static void _assertOverridesAreSound(
    List<CobaltOverride<Object>> overrides,
    String scopeName,
  ) {
    final seen = <CobaltKey>{};
    for (final override in overrides) {
      if (override.key.type == Object) {
        throw CobaltOverrideError(override.key, scopeName);
      }
      if (!seen.add(override.key)) {
        throw CobaltDuplicateRegistrationError(override.key, scopeName);
      }
    }
  }

  void _applyOverrides(List<CobaltOverride<Object>> overrides) {
    if (overrides.isEmpty) return;
    _applyingOverrides = true;
    try {
      for (final override in overrides) {
        override.applyTo(this);
      }
    } finally {
      _applyingOverrides = false;
    }
  }

  /// Wraps what the registration of [T] in this scope produces.
  ///
  /// Decorators apply in the order they are added, the first innermost, to
  /// whatever the registration hands out — an override included. A retained
  /// registration is decorated once, the first time it is resolved, and
  /// callers share the result; a transient or parameterized one is decorated
  /// every time it is built. The order of [decorate] and the registration
  /// inside a builder does not matter.
  ///
  /// The scope keeps owning the inner instance and closes it once; the
  /// decorator is not closed.
  ///
  /// A key already resolved from this scope throws [CobaltDecoratorError]:
  /// whoever holds it would keep the undecorated instance. A decorator for a
  /// key this scope does not register wraps nothing, and [runBuilder] reports
  /// that once the builder returns, naming the ancestor that owns it.
  void decorate<T extends Object>(
    CobaltDecorator<T> decorator, {
    String? name,
  }) {
    _assertUsable();
    final key = CobaltKey(T, name: name);
    if (_served.contains(key)) throw CobaltDecoratorError.late(key, this.name);
    (_decorators[key] ??= []).add(
      _Decoration(
        decorator.runtimeType,
        (inner, resolver) => decorator.decorate(inner as T, resolver),
      ),
    );
  }

  /// Registers [T] so every resolution builds a new instance.
  ///
  /// The scope does not retain what it builds, so transient instances are the
  /// caller's to dispose.
  void registerFactory<T extends Object>(
    CobaltFactory<T> factory, {
    String? name,
  }) {
    _put(
      TransientRegistration(
        key: CobaltKey(T, name: name),
        order: _order++,
        factory: factory,
      ),
    );
  }

  /// Registers an already-built [value] as the single instance of [T].
  ///
  /// The scope takes ownership immediately: if [value] is disposable it is
  /// torn down with the scope, in registration order relative to everything
  /// else it owns.
  ///
  /// [dispose] closes a [value] whose type implements neither [Disposable] nor
  /// [AsyncDisposable] — a client from another package, say. Without it such a
  /// value is registered but never closed, because the scope has no way to
  /// know how.
  ///
  /// When an override replaces [T], [value] is not registered but is still
  /// owned and closed with the scope: it was built before the scope could say
  /// no, and dropping it would leak whatever it holds. Prefer
  /// [registerEagerSingleton] where the value is expensive to build.
  void registerSingleton<T extends Object>(
    T value, {
    String? name,
    FutureOr<void> Function(T instance)? dispose,
  }) {
    _put(
      SingletonRegistration(
        key: CobaltKey(T, name: name),
        order: _order++,
        value: value,
      ),
    );
    _own(value, teardown: _teardownOf(dispose));
  }

  /// Builds [T] with [factory] now and registers it as the single instance.
  ///
  /// The eager counterpart of [registerLazySingleton]. It differs from
  /// [registerSingleton] in who builds: here the scope does, so the instance
  /// is reported to observers like any other, a failed resolution inside
  /// [factory] names the chain, and an override of [T] means [factory] is
  /// never called at all — where a value handed to [registerSingleton] already
  /// exists before the scope can decide.
  ///
  /// [dispose] closes an instance whose type implements neither [Disposable]
  /// nor [AsyncDisposable].
  void registerEagerSingleton<T extends Object>(
    CobaltFactory<T> factory, {
    String? name,
    FutureOr<void> Function(T instance)? dispose,
  }) {
    final key = CobaltKey(T, name: name);
    if (!_admit(key)) return;
    final order = _order++;
    final teardown = _teardownOf(dispose);
    final instance = _tracker.guard(key, () {
      final built = factory.create(this);
      _afterCreate(
        built,
        key,
        kind: CobaltRegistrationKind.singleton,
        retain: true,
        teardown: teardown,
      );
      return built;
    });
    _registrations[key] = SingletonRegistration(
      key: key,
      order: order,
      value: instance,
    );
  }

  /// Registers [T] so the first resolution builds it and later ones reuse it.
  ///
  /// The instance is retained and disposed with the scope. Because it is built
  /// on demand, its position in the teardown order follows when it was
  /// *created*, not when it was registered.
  /// [dispose] closes an instance whose type implements neither [Disposable]
  /// nor [AsyncDisposable].
  void registerLazySingleton<T extends Object>(
    CobaltFactory<T> factory, {
    String? name,
    FutureOr<void> Function(T instance)? dispose,
  }) {
    _put(
      LazySingletonRegistration(
        key: CobaltKey(T, name: name),
        order: _order++,
        factory: factory,
        teardown: _teardownOf(dispose),
      ),
    );
  }

  /// Registers [T] as a single instance built during [init].
  ///
  /// [dependsOn] declares which other async registrations must finish first.
  /// The graph is sorted into levels: everything in a level runs through
  /// `Future.wait`, and the next level waits for it. A cycle throws
  /// `CobaltCycleError`.
  ///
  /// Resolving [T] before [init] completes throws `CobaltNotReadyError`.
  /// [dispose] closes an instance whose type implements neither [Disposable]
  /// nor [AsyncDisposable].
  void registerAsyncSingleton<T extends Object>(
    CobaltAsyncFactory<T> factory, {
    String? name,
    Set<CobaltKey> dependsOn = const {},
    FutureOr<void> Function(T instance)? dispose,
  }) {
    _assertPhaseOneIsStillOpen(CobaltKey(T, name: name));
    _put(
      AsyncSingletonRegistration(
        key: CobaltKey(T, name: name),
        order: _order++,
        factory: factory,
        dependsOn: dependsOn,
        teardown: _teardownOf(dispose),
      ),
    );
  }

  /// Registers [T] as a single instance built by the first [getAsync].
  ///
  /// For something expensive that lives as long as this scope but is wanted
  /// by few of the screens under it: nothing is built during [init], so it
  /// costs nothing until someone asks. The instance is retained and disposed
  /// with the scope, in the order it was *created*.
  ///
  /// Unlike [registerAsyncSingleton] this may be called after [init], because
  /// there is no phase to miss. An async singleton cannot name this one in its
  /// `dependsOn` — `init()` has nothing to wait for — and throws
  /// `CobaltDependsOnError` if it does.
  ///
  /// [dispose] closes an instance whose type implements neither [Disposable]
  /// nor [AsyncDisposable].
  void registerLazyAsyncSingleton<T extends Object>(
    CobaltAsyncFactory<T> factory, {
    String? name,
    FutureOr<void> Function(T instance)? dispose,
  }) {
    _put(
      LazyAsyncSingletonRegistration(
        key: CobaltKey(T, name: name),
        order: _order++,
        factory: factory,
        teardown: _teardownOf(dispose),
      ),
    );
  }

  /// Refuses an async registration that phase 1 can no longer build.
  ///
  /// [init] collects what to build once, at its start, and memoizes its own
  /// future — so a registration added at or after that moment is never built
  /// and every resolve of it throws for the rest of the scope's life. That
  /// used to be accepted in silence, and the error it eventually produced said
  /// the key "was requested before init()", which by then was untrue.
  ///
  /// Sync registrations stay allowed at any point: they are built on demand
  /// and have no phase to miss.
  void _assertPhaseOneIsStillOpen(CobaltKey key) {
    if (_state != CobaltScopeState.initializing &&
        _state != CobaltScopeState.active) {
      return;
    }
    throw CobaltScopeStateError(
      'Scope "$name" is $_state, so $key would never be built: init() takes '
      'the async registrations it finds when it starts, and runs once. '
      'Register it before init(), or push a child scope and initialize that.',
    );
  }

  /// Registers [T] as a factory taking a runtime argument of type [P].
  ///
  /// Resolve it with [getWithParam]; a plain [get] throws, because the
  /// container has no value to pass.
  void registerParamFactory<T extends Object, P extends Object>(
    CobaltParamFactory<T, P> factory, {
    String? name,
  }) {
    _put(
      ParamRegistration(
        key: CobaltKey(T, name: name),
        order: _order++,
        factory: factory,
        paramType: P,
        accepts: (value) => value is P,
      ),
    );
  }

  @override
  bool isRegistered<T extends Object>({String? name}) =>
      _lookup(CobaltKey(T, name: name)) != null;

  @override
  T? getOrNull<T extends Object>({String? name}) {
    _assertUsable();
    final found = _lookup(CobaltKey(T, name: name));
    if (found == null) return null;
    return found.scope._materialize(found.registration) as T;
  }

  @override
  T get<T extends Object>({String? name}) {
    _assertUsable();
    final key = CobaltKey(T, name: name);
    final found = _lookup(key);
    if (found == null) {
      throw CobaltNotRegisteredError(
        key,
        this.name,
        resolving: _trail(),
        whileBuilding: _building,
      );
    }
    return found.scope._materialize(found.registration) as T;
  }

  @override
  Future<T> getAsync<T extends Object>({String? name}) async {
    _assertUsable();
    final key = CobaltKey(T, name: name);
    final found = _lookup(key);
    if (found == null) {
      throw CobaltNotRegisteredError(
        key,
        this.name,
        resolving: _trail(),
        whileBuilding: _building,
      );
    }
    return await found.scope._resolveAsync(found.registration) as T;
  }

  @override
  Future<List<T>> getAllAsync<T extends Object>() async {
    _assertUsable();
    final seen = <CobaltKey>{};
    final result = <T>[];
    for (CobaltScope? scope = this; scope != null; scope = scope.parent) {
      for (final registration in scope._registrations.values.toList()) {
        if (registration.key.type != T) continue;
        if (!seen.add(registration.key)) continue;
        result.add(await scope._resolveAsync(registration) as T);
      }
    }
    return result;
  }

  @override
  T getWithParam<T extends Object, P extends Object>(P param, {String? name}) {
    _assertUsable();
    final key = CobaltKey(T, name: name);
    final found = _lookup(key);
    if (found == null) {
      throw CobaltNotRegisteredError(
        key,
        this.name,
        resolving: _trail(),
        whileBuilding: _building,
      );
    }
    final registration = found.registration;
    if (registration is! ParamRegistration) {
      throw CobaltNotParameterizedError(key);
    }
    if (!registration.accepts(param)) {
      throw CobaltParamTypeError(
        key,
        registration.paramType,
        param.runtimeType,
      );
    }
    return found.scope._tracker.guard(key, () {
      final instance = registration.factory.create(found.scope, param);
      found.scope._afterCreate(
        instance,
        key,
        kind: CobaltRegistrationKind.parameterized,
        retain: false,
      );
      return found.scope._serveFresh(key, instance) as T;
    });
  }

  @override
  List<T> getAll<T extends Object>() {
    _assertUsable();
    final seen = <CobaltKey>{};
    final result = <T>[];
    for (CobaltScope? scope = this; scope != null; scope = scope.parent) {
      // No sort: `_registrations` is insertion-ordered and `_put` only ever
      // inserts — a duplicate key throws — so iterating it is already
      // ascending `order`. Sorting a copy of the matches said the same thing
      // at the cost of a list per call.
      for (final registration in scope._registrations.values) {
        if (registration.key.type != T) continue;
        if (!seen.add(registration.key)) continue;
        result.add(scope._materialize(registration) as T);
      }
    }
    return result;
  }

  /// Builds every async singleton registered in this scope.
  ///
  /// Safe to call more than once and from several places at once: the work
  /// runs exactly once and every caller awaits the same future. Returns
  /// immediately for a scope that is already active.
  ///
  /// If it throws, the scope stays usable enough to be disposed, and whatever
  /// was built before the failure is still torn down.
  Future<void> init() {
    final pending = _initFuture;
    if (pending != null) return pending;
    if (_state == CobaltScopeState.active) return Future<void>.value();
    _assertUsable();
    return _initFuture = _run();
  }

  /// Rejects a `dependsOn` that names something phase 1 cannot wait for.
  ///
  /// An edge to a key outside this scope's async registrations used to be
  /// dropped without a word, so the declaration read as an ordering guarantee
  /// that was never in force. There are three ways to be outside that set and
  /// only one of them is innocent:
  ///
  /// - nothing registers the key at all — a mistake, and the loudest kind;
  /// - something registers it, but not as an async singleton — the wait is
  ///   meaningless, because a registration without an async build has nothing
  ///   to finish;
  /// - an ancestor registers it as an async singleton — legitimate, and still
  ///   dropped: a parent's phase 1 is its own, and a child pushed onto a live
  ///   parent finds it already built.
  void _assertDependsOnCanBeWaitedFor(
    List<AsyncSingletonRegistration> pending,
    Map<CobaltKey, AsyncSingletonRegistration> byKey,
  ) {
    for (final registration in pending) {
      for (final dependency in registration.dependsOn) {
        if (byKey.containsKey(dependency)) continue;
        final found = _lookup(dependency);
        if (found != null && found.scope._overriddenKeys.contains(dependency)) {
          continue;
        }
        if (found == null) {
          throw CobaltDependsOnError(
            registration.key,
            dependency,
            reason: 'nothing registers',
          );
        }
        if (found.registration is LazyAsyncSingletonRegistration) {
          throw CobaltDependsOnError(
            registration.key,
            dependency,
            reason:
                'is a lazy async registration, built by the first getAsync '
                'rather than by init()',
          );
        }
        if (found.registration is! AsyncSingletonRegistration) {
          throw CobaltDependsOnError(
            registration.key,
            dependency,
            reason: 'is registered but not as an async singleton',
          );
        }
      }
    }
  }

  Future<void> _run() async {
    _state = CobaltScopeState.initializing;

    final pending =
        _registrations.values.whereType<AsyncSingletonRegistration>().toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    if (pending.isNotEmpty) {
      final byKey = {for (final r in pending) r.key: r};
      _assertDependsOnCanBeWaitedFor(pending, byKey);
      final levels = layeredTopologicalSort<AsyncSingletonRegistration>(
        pending,
        (r) => [for (final dep in r.dependsOn) ?byKey[dep]],
        labelOf: (r) => r.key.toString(),
      );

      final building = Stopwatch()..start();
      _notify((observer) => observer.onScopeInitStarted(ref, levels.length));
      try {
        for (final level in levels) {
          await Future.wait([for (final r in level) _createAsync(r)]);
        }
      } catch (error, stackTrace) {
        _notify(
          (observer) => observer.onScopeInitFailed(ref, error, stackTrace),
        );
        rethrow;
      }
      _notify(
        (observer) => observer.onScopeInitCompleted(ref, building.elapsed),
      );
    }

    if (_state == CobaltScopeState.initializing) {
      _state = CobaltScopeState.active;
    }
  }

  /// Ties [instance]'s lifetime to this scope without registering it.
  ///
  /// The scope disposes it along with everything else it owns, in the same
  /// reverse-creation order, but nothing can resolve it — use this for objects
  /// that belong to the scope's lifetime yet are not dependencies. Bootstrap
  /// steps are the built-in case: they run before any container exists, so
  /// they cannot be registered, but whatever they opened still has to be
  /// closed.
  ///
  /// Objects that implement neither [Disposable] nor [AsyncDisposable] are
  /// returned unchanged and not retained, since there would be nothing to do
  /// with them at teardown — unless [dispose] says what to do, in which case
  /// they are retained and it is called.
  ///
  /// Returns [instance], so it can be adopted inline.
  T adopt<T extends Object>(
    T instance, {
    FutureOr<void> Function(T instance)? dispose,
  }) {
    _assertUsable();
    _own(instance, teardown: _teardownOf(dispose));
    return instance;
  }

  /// The budget [dispose] uses when the caller does not pass one.
  static const defaultDisposeTimeout = Duration(seconds: 30);

  /// Tears the scope down and detaches it from its parent.
  ///
  /// Children go first, in reverse push order, then this scope's own
  /// instances in reverse creation order. `AsyncDisposable.dispose` is
  /// awaited before moving on, so ordering holds even when teardown does I/O.
  ///
  /// Idempotent, and safe to call while [init] is still running — it waits for
  /// it, so nothing that init built escapes teardown. After this the scope is
  /// permanently unusable.
  ///
  /// Teardown is best-effort. A step that throws, or that runs past the
  /// deadline, is recorded and the remaining steps still run, so one broken
  /// object cannot strand everything registered after it. [timeout] is a
  /// deadline for the whole teardown rather than per step, so this returns
  /// within roughly that long however many objects are involved.
  ///
  /// The scope always reaches [CobaltScopeState.disposed]. If anything went
  /// wrong, [CobaltDisposeError] is thrown afterwards listing every failure.
  /// Timed-out steps were abandoned, not cancelled — Dart cannot cancel a
  /// future — which is why they are reported rather than ignored.
  ///
  /// An `init()` still running when this is called is waited for. If it
  /// *threw*, that is not a teardown failure and does not make this throw on
  /// its own — the error belongs to whoever called `init()` and was already
  /// delivered there. It is still recorded, tagged
  /// [CobaltDisposeStage.awaitingInit], so that when teardown does fail the
  /// report says the scope was only half-built. If instead the wait ran past
  /// the deadline, that is teardown failing to finish, and it is reported like
  /// any other overrun.
  Future<void> dispose({Duration timeout = defaultDisposeTimeout}) async {
    if (_state == CobaltScopeState.disposed ||
        _state == CobaltScopeState.disposing) {
      return;
    }
    _closing = true;

    final elapsed = Stopwatch()..start();
    final failures = <CobaltDisposeFailure>[];

    Duration remaining() => timeout - elapsed.elapsed;

    Future<void> within(
      String label,
      Future<void> Function() step, {
      CobaltDisposeStage stage = CobaltDisposeStage.releasing,
    }) async {
      final left = remaining();
      if (left <= Duration.zero) {
        failures.add(
          CobaltDisposeFailure(
            label,
            TimeoutException('the teardown deadline had already passed'),
            StackTrace.current,
            stage: stage,
          ),
        );
        return;
      }
      try {
        await step().timeout(left);
      } catch (error, stackTrace) {
        failures.add(
          CobaltDisposeFailure(label, error, stackTrace, stage: stage),
        );
      }
    }

    final pendingInit = _initFuture;
    if (pendingInit != null) {
      // Awaiting this future makes Cobalt its error listener, which would
      // suppress the unhandled-error report Dart makes for an init() nobody
      // awaited. The failure is recorded instead of dropped, tagged so a
      // caller that already handled it can tell it apart from teardown.
      await within(
        'init',
        () => pendingInit,
        stage: CobaltDisposeStage.awaitingInit,
      );
      if (_state == CobaltScopeState.disposed ||
          _state == CobaltScopeState.disposing) {
        return;
      }
    }

    for (final building in _lazyBuilding.toList(growable: false)) {
      final inFlight = building.inFlight;
      if (inFlight == null) continue;
      await within(
        '${building.key} (lazy build)',
        () => inFlight,
        stage: CobaltDisposeStage.awaitingLazyBuild,
      );
    }
    if (_state == CobaltScopeState.disposed ||
        _state == CobaltScopeState.disposing) {
      return;
    }

    _state = CobaltScopeState.disposing;
    _notify((observer) => observer.onScopeDisposeStarted(ref));

    for (final child in _children.reversed.toList(growable: false)) {
      try {
        await child.dispose(timeout: remaining());
      } on CobaltDisposeError catch (error) {
        failures.addAll([
          for (final failure in error.failures)
            CobaltDisposeFailure(
              '${child.name}/${failure.label}',
              failure.error,
              failure.stackTrace,
            ),
        ]);
      } catch (error, stackTrace) {
        failures.add(
          CobaltDisposeFailure('${child.name}/dispose', error, stackTrace),
        );
      }
    }
    _children.clear();

    for (final owned in _owned.reversed.toList(growable: false)) {
      final instance = owned.instance;
      final label = '${instance.runtimeType}.dispose';

      final teardown = owned.teardown;
      if (teardown != null) {
        final before = failures.length;
        await within(label, () async => teardown(instance));
        if (failures.length == before) {
          _notify(
            (observer) =>
                observer.onInstanceDisposed(ref, '${instance.runtimeType}'),
          );
        }
        continue;
      }

      switch (instance) {
        case AsyncDisposable():
          final before = failures.length;
          await within(label, instance.dispose);
          if (failures.length == before) {
            _notify(
              (observer) =>
                  observer.onInstanceDisposed(ref, '${instance.runtimeType}'),
            );
          }
        case Disposable():
          try {
            instance.dispose();
            _notify(
              (observer) =>
                  observer.onInstanceDisposed(ref, '${instance.runtimeType}'),
            );
          } catch (error, stackTrace) {
            failures.add(CobaltDisposeFailure(label, error, stackTrace));
          }
      }
    }

    _owned.clear();
    _registrations.clear();
    _decorators.clear();
    _decorated.clear();
    _initFuture = null;
    parent?._children.remove(this);
    _state = CobaltScopeState.disposed;

    // An init that threw belongs to whoever called init(); an init that ran
    // past the deadline is teardown failing to finish its own wait.
    _notify(
      (observer) => observer.onScopeDisposed(
        ref,
        elapsed.elapsed,
        List.unmodifiable(failures),
      ),
    );

    final couldNotRelease = failures.any(
      (failure) => !failure.isBuildFailure || failure.isTimeout,
    );
    if (couldNotRelease) {
      throw CobaltDisposeError(name, failures);
    }
  }

  void _put(CobaltRegistration registration) {
    if (_admit(registration.key)) {
      _registrations[registration.key] = registration;
    }
  }

  /// Whether a registration of [key] should go in, or be skipped because an
  /// override already holds it.
  ///
  /// A key claimed once is a key registered once: registering it a second time
  /// is the duplicate it would have been without the override.
  bool _admit(CobaltKey key) {
    _assertUsable();
    if (!_applyingOverrides && _overriddenKeys.contains(key)) {
      if (!_claimed.add(key)) {
        throw CobaltDuplicateRegistrationError(key, name);
      }
      _notify((observer) => observer.onRegistrationOverridden(ref, key));
      return false;
    }
    if (_registrations.containsKey(key)) {
      throw CobaltDuplicateRegistrationError(key, name);
    }
    if (_applyingOverrides) _overriddenKeys.add(key);
    return true;
  }

  ({CobaltScope scope, CobaltRegistration registration})? _lookup(
    CobaltKey key,
  ) {
    for (CobaltScope? scope = this; scope != null; scope = scope.parent) {
      final registration = scope._registrations[key];
      if (registration != null) {
        return (scope: scope, registration: registration);
      }
    }
    return null;
  }

  Object _materialize(CobaltRegistration registration) {
    switch (registration) {
      case SingletonRegistration():
        return _serve(registration.key, registration.value);

      case TransientRegistration():
        return _tracker.guard(registration.key, () {
          final instance = registration.factory.create(this);
          _afterCreate(
            instance,
            registration.key,
            kind: CobaltRegistrationKind.transient,
            retain: false,
          );
          return _serveFresh(registration.key, instance);
        });

      case LazySingletonRegistration():
        final existing =
            registration.instance ??
            _tracker.guard<Object>(registration.key, () {
              final instance = registration.factory.create(this);
              registration.instance = instance;
              _afterCreate(
                instance,
                registration.key,
                kind: CobaltRegistrationKind.lazySingleton,
                retain: true,
                teardown: registration.teardown,
              );
              return instance;
            });
        return _serve(registration.key, existing);

      case AsyncSingletonRegistration():
        final existing = registration.instance;
        if (existing == null || !registration.isReady) {
          throw CobaltNotReadyError(registration.key, resolving: _trail());
        }
        return _serve(registration.key, existing);

      case LazyAsyncSingletonRegistration():
        final existing = registration.instance;
        if (existing != null) return _serve(registration.key, existing);
        throw CobaltLazyAsyncError(registration.key, resolving: _trail());

      case ParamRegistration():
        throw CobaltParamRequiredError(registration.key);
    }
  }

  /// [_materialize] for [getAsync]: builds a lazy async registration, and
  /// waits for an async singleton `init()` is still building.
  Future<Object> _resolveAsync(CobaltRegistration registration) async {
    switch (registration) {
      case LazyAsyncSingletonRegistration():
        return _serve(registration.key, await _buildLazy(registration));

      case AsyncSingletonRegistration():
        final existing = registration.instance;
        if (existing != null && registration.isReady) {
          return _serve(registration.key, existing);
        }
        final pending = _initFuture;
        if (pending == null ||
            identical(CobaltResolutionTracker.phaseOneOwner, this)) {
          throw CobaltNotReadyError(registration.key, resolving: _trail());
        }
        await pending;
        final built = registration.instance;
        if (built != null && registration.isReady) {
          return _serve(registration.key, built);
        }
        throw CobaltNotReadyError(registration.key, resolving: _trail());

      case SingletonRegistration() ||
          LazySingletonRegistration() ||
          TransientRegistration() ||
          ParamRegistration():
        return _materialize(registration);
    }
  }

  /// Builds [registration] once, however many callers ask at the same time.
  ///
  /// Every concurrent caller awaits the one future in flight. A build that
  /// fails is not cached: the next call starts a fresh one.
  ///
  /// The build is marked in flight before the factory is called, because an
  /// async factory runs synchronously up to its first `await`: a chain that
  /// closes on itself in that stretch has to find the key already building.
  Future<Object> _buildLazy(LazyAsyncSingletonRegistration registration) {
    final existing = registration.instance;
    if (existing != null) return Future.value(existing);

    final inFlight = registration.inFlight;
    if (inFlight != null) {
      if (CobaltResolutionTracker.lazyChain.contains(registration.key)) {
        return CobaltResolutionTracker.guardLazy(
          registration.key,
          () => inFlight,
        );
      }
      return inFlight;
    }

    if (_closing || !isUsable) {
      return Future.error(
        CobaltScopeStateError(
          'Scope "$name" is being disposed, so ${registration.key} will not '
          'be built.',
        ),
      );
    }

    final completer = Completer<Object>();
    final build = completer.future;
    registration.inFlight = build;
    _lazyBuilding.add(registration);
    build.then(
      (_) => _settleLazy(registration, build),
      onError: (Object _) => _settleLazy(registration, build),
    );

    CobaltResolutionTracker.guardLazy(registration.key, () async {
      final instance = await registration.factory.create(this);
      if (_state == CobaltScopeState.disposing ||
          _state == CobaltScopeState.disposed) {
        try {
          await _releaseLate(instance, registration.teardown);
        } catch (error, stackTrace) {
          Zone.current.handleUncaughtError(error, stackTrace);
        }
        throw CobaltScopeStateError(
          'Scope "$name" was disposed while ${registration.key} was being '
          'built. The instance was closed as soon as it arrived.',
        );
      }
      registration.instance = instance;
      _afterCreate(
        instance,
        registration.key,
        kind: CobaltRegistrationKind.lazyAsyncSingleton,
        retain: true,
        teardown: registration.teardown,
      );
      return instance;
    }).then(completer.complete, onError: completer.completeError);

    return build;
  }

  void _settleLazy(
    LazyAsyncSingletonRegistration registration,
    Future<Object> build,
  ) {
    if (identical(registration.inFlight, build)) registration.inFlight = null;
    _lazyBuilding.remove(registration);
  }

  /// Closes an instance that finished building after its scope was torn down.
  static Future<void> _releaseLate(
    Object instance,
    CobaltTeardown? teardown,
  ) async {
    if (teardown != null) {
      await teardown(instance);
      return;
    }
    switch (instance) {
      case AsyncDisposable():
        await instance.dispose();
      case Disposable():
        instance.dispose();
    }
  }

  /// What is being built, outermost first: the lazy async builds that led
  /// here, then the synchronous chain below them.
  List<CobaltKey> _trail() => [
    ...CobaltResolutionTracker.lazyChain,
    ..._tracker.chain,
  ];

  Future<void> _createAsync(AsyncSingletonRegistration registration) =>
      _tracker.guardAsync(registration.key, () async {
        final instance = await CobaltResolutionTracker.inPhaseOne(
          this,
          () => registration.factory.create(this),
        );
        registration.instance = instance;
        registration.isReady = true;
        _afterCreate(
          instance,
          registration.key,
          kind: CobaltRegistrationKind.asyncSingleton,
          retain: true,
          teardown: registration.teardown,
        );
      });

  /// Hands out a retained instance, decorated once and shared from then on.
  Object _serve(CobaltKey key, Object inner) {
    _served.add(key);
    final decorations = _decorators[key];
    if (decorations == null) return inner;
    return _decorated[key] ??= _tracker.guard(
      key,
      () => _applyDecorations(decorations, inner),
    );
  }

  /// Hands out an instance built for this one call, decorated on its own.
  ///
  /// Called inside the build's own guard, which already holds [key].
  Object _serveFresh(CobaltKey key, Object inner) {
    _served.add(key);
    final decorations = _decorators[key];
    if (decorations == null) return inner;
    return _applyDecorations(decorations, inner);
  }

  Object _applyDecorations(List<_Decoration> decorations, Object inner) {
    var current = inner;
    for (final decoration in decorations) {
      current = decoration.apply(current, this);
    }
    return current;
  }

  void _afterCreate(
    Object instance,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retain,
    CobaltTeardown? teardown,
  }) {
    if (instance is CobaltInjectable) instance.onInject(this);
    if (retain) _own(instance, teardown: teardown);
    _notify(
      (observer) =>
          observer.onInstanceCreated(ref, key, kind: kind, retained: retain),
    );
  }

  /// Erases the caller's typed callback down to what a registration can hold.
  ///
  /// The cast is safe: the callback only ever reaches the instance registered
  /// under its own `T`.
  static CobaltTeardown? _teardownOf<T extends Object>(
    FutureOr<void> Function(T instance)? dispose,
  ) => dispose == null ? null : (instance) => dispose(instance as T);

  void _own(Object instance, {CobaltTeardown? teardown}) {
    if (teardown != null ||
        instance is Disposable ||
        instance is AsyncDisposable) {
      _owned.add(_OwnedInstance(instance, teardown));
    }
  }

  /// Whether a builder is running against this scope right now.
  ///
  /// Only [runBuilder] sets it, and only for the length of one call. It exists
  /// so a failed resolution can tell "not registered yet" from "not
  /// registered": inside the window the registration may be three lines below,
  /// outside it there is nothing to add. The scope state cannot answer this —
  /// it is `open` during composition and `open` afterwards, and a test scope
  /// that never calls init() stays `open` for its whole life.
  var _building = false;

  /// Runs [builder] against this scope.
  ///
  /// Prefer this to calling `builder.build(scope)` yourself: what it adds is
  /// the window above, and with it the diagnostic that tells a reader their
  /// eager registration ran before the one it needed.
  ///
  /// It also checks, once [builder] returns, that every override handed to
  /// this scope replaced something, and throws [CobaltOverrideError] naming
  /// the first that did not.
  void runBuilder(CobaltScopeBuilder builder) {
    _building = true;
    try {
      builder.build(this);
    } finally {
      _building = false;
    }
    _assertOverridesClaimed();
    _assertDecoratorsOwned();
  }

  void _assertDecoratorsOwned() {
    for (final key in _decorators.keys) {
      if (_registrations.containsKey(key)) continue;
      throw CobaltDecoratorError.notOwned(
        key,
        name,
        owner: parent?._lookup(key)?.scope.name,
      );
    }
  }

  void _assertOverridesClaimed() {
    for (final key in _overriddenKeys) {
      if (_claimed.contains(key)) continue;
      throw CobaltOverrideError(
        key,
        name,
        owner: parent?._lookup(key)?.scope.name,
      );
    }
  }

  /// How this scope is described to an [CobaltObserver].
  CobaltScopeRef get ref =>
      CobaltScopeRef(name: name, depth: depth, parentName: parent?.name);

  /// Runs [event] on every observer, swallowing anything it throws.
  ///
  /// Watching must not be able to break the graph being watched, and there is
  /// nowhere to report an observer's own failure to — reporting is the thing
  /// that just failed.
  void _notify(void Function(CobaltObserver observer) event) {
    if (_observers.isEmpty) return;
    for (final observer in _observers) {
      try {
        event(observer);
      } catch (_) {
        // Deliberately ignored; see above.
      }
    }
  }

  void _assertUsable() {
    if (!isUsable) {
      throw CobaltScopeStateError(
        'Scope "$name" is $_state and cannot be used.',
      );
    }
  }

  @override
  String toString() => 'CobaltScope($name, $_state)';
}

/// A decorator with its type erased to what a scope can store.
class _Decoration {
  _Decoration(this.type, this.apply);

  final Type type;
  final Object Function(Object inner, CobaltResolver resolver) apply;
}

/// An instance the scope owns, with whatever closes it.
///
/// [teardown] is null for the common case, where the instance says how to
/// close itself by implementing [Disposable] or [AsyncDisposable].
class _OwnedInstance {
  _OwnedInstance(this.instance, this.teardown);

  final Object instance;
  final CobaltTeardown? teardown;
}
