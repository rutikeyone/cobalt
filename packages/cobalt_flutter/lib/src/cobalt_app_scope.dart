import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_flutter/src/cobalt_app_scope_controller.dart';
import 'package:cobalt_flutter/src/cobalt_scope_provider.dart';
import 'package:cobalt_flutter/src/errors/cobalt_no_app_scope_error.dart';
import 'package:flutter/widgets.dart';

/// Owns the root scope for as long as the app is mounted.
///
/// Declares the graph the same way [CobaltApplication.start] takes it, builds
/// it, publishes it, and disposes it on unmount. The counterpart to
/// [CobaltScopeWidget], which owns a *child* scope; this one has no ancestor to
/// push from, so it starts the graph itself.
///
/// The usual place for it is [MaterialApp.builder], through
/// [CobaltAppScope.builder] — there [loading] and [errorBuilder] are rendered
/// with the app's theme and directionality, so they can be an ordinary screen
/// rather than a second app:
///
/// ```dart
/// void main() => runApp(
///   MaterialApp(
///     theme: ThemeData(colorSchemeSeed: Colors.indigo),
///     builder: CobaltAppScope.builder(
///       root: const AppScope(),
///       loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
///     ),
///     home: const HomeScreen(),
///   ),
/// );
/// ```
///
/// Awaiting the graph inside `runApp` rather than before it buys two things:
/// a startup failure becomes a screen with a retry instead of an app that dies
/// without a frame, and `WidgetsFlutterBinding` is already initialized when
/// `@CobaltBootstrap` steps run.
///
/// `CobaltAppScope.of(context).restart()` tears the graph down and builds a new
/// one — the same call that retries a failed start.
class CobaltAppScope extends StatefulWidget {
  /// Creates the owner of an app's root scope from the graph's parts.
  ///
  /// In Code-Gen Mode these are the generated `$CobaltRootScope`,
  /// `$cobaltBootstrap` and `$cobaltRootScopeName`.
  const CobaltAppScope({
    required CobaltScopeBuilder this.root,
    required this.child,
    this.bootstrap,
    this.rootName = 'root',
    this.observers = const [],
    this.overrides,
    this.warmUp = const [],
    this.loading,
    this.errorBuilder,
    this.disposeOnExitRequest = false,
    super.key,
  }) : start = null;

  /// Creates the owner from a function that returns a started scope.
  ///
  /// The escape hatch for a graph the declarative form cannot express — one
  /// assembled conditionally, or handed over by something else entirely. Use
  /// the default constructor when it fits, because it is the one that keeps
  /// [bootstrap] honest across restarts.
  const CobaltAppScope.start({
    required Future<CobaltScope> Function() this.start,
    required this.child,
    this.warmUp = const [],
    this.loading,
    this.errorBuilder,
    this.disposeOnExitRequest = false,
    super.key,
  }) : root = null,
       bootstrap = null,
       rootName = 'root',
       observers = const [],
       overrides = null;

  /// Declares what the root scope contains. Null only for [CobaltAppScope.start].
  final CobaltScopeBuilder? root;

  /// Produces the phase-0 steps, called once per start.
  ///
  /// A function and not a list, deliberately. Bootstrap steps are instances
  /// that hold resources — a stored list would hand a restart the same objects
  /// it just released. An [CobaltScopeBuilder] carries no such risk, which is
  /// why [root] *is* a value: it only registers, and the generated one is
  /// `const`.
  ///
  /// In Code-Gen Mode this is `() => $cobaltBootstrap` — or
  /// `() => $cobaltBootstrap(environment)` once environments are in play.
  final List<CobaltBootstrapStep> Function()? bootstrap;

  /// Names the root scope in diagnostics. `$cobaltRootScopeName` when generated.
  final String rootName;

  /// Observers for the whole tree; child scopes inherit them.
  final List<CobaltObserver> observers;

  /// Produces replacements for registrations [root] makes, called once per
  /// start.
  ///
  /// A function and not a list, for the reason [bootstrap] is one: the scope
  /// owns a replacement handed over with `CobaltOverride.value` and disposes it
  /// with the graph, so a stored list would hand a restart the very object the
  /// previous graph just closed.
  ///
  /// A flavour or a debug menu is the case this serves in an app, a widget
  /// test the case it serves everywhere else. An override is never silent:
  /// observers are told each time a registration is skipped for one. See
  /// [CobaltOverride].
  final List<CobaltOverride<Object>> Function()? overrides;

  /// Lazy async registrations to start building as soon as the graph is up.
  ///
  /// For something expensive that a later screen needs and that should not
  /// sit on the startup path: [loading] gives way to [child] as soon as the
  /// graph is ready, and these build behind it — the same builds `getAsync`
  /// would start, so a screen that asks early simply waits for the one in
  /// flight. See [CobaltScope.warmUp].
  ///
  /// A failure does not replace the app with [errorBuilder]; the app is
  /// running by then. It goes to `FlutterError.reportError`, like a failed
  /// teardown, and the next `getAsync` of that key tries again.
  final List<CobaltKey> warmUp;

  /// Builds the root scope. Null unless built with [CobaltAppScope.start].
  ///
  /// Read once, when the widget first mounts. There is no `didUpdateWidget`:
  /// handed a different graph in the same slot, this widget keeps the one it
  /// already owns, and the next resolve looks in the wrong graph. Give it a
  /// `key` when the graph can change — [CobaltAppScopeController.restart] is
  /// how you replace a graph deliberately.
  final Future<CobaltScope> Function()? start;

  /// Shown once the graph is ready, below an [CobaltScopeProvider].
  final Widget child;

  /// Shown while the graph starts, and again while a restart is in flight.
  final Widget? loading;

  /// Shown when the start throws. `retry` runs it again.
  ///
  /// Without it the error is rethrown during build, surfacing through the
  /// usual Flutter error handling — the same rule [CobaltScopeWidget] follows.
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
  errorBuilder;

  /// Whether to dispose the graph when the OS asks the app to quit.
  ///
  /// Off by default, and deliberately. The hook behind it,
  /// `AppLifecycleListener.onExitRequested`, fires only where an exit is
  /// cancelable — currently macOS and Linux — and Flutter's own documentation
  /// is blunt about the rest: "Do not rely on this function as a place to save
  /// critical data, because you will be disappointed." On iOS and Android the
  /// process can be killed with no notification at all.
  ///
  /// So this is a desktop nicety, not a guarantee, and turning it on delays
  /// quitting by however long teardown takes — up to
  /// [CobaltScope.defaultDisposeTimeout].
  ///
  /// One sharp edge: Flutter asks *every* observer before quitting and does
  /// not stop at the first refusal. If another observer cancels the exit after
  /// this one has already disposed, the app keeps running with no graph and
  /// shows [loading] until something calls
  /// [CobaltAppScopeController.restart].
  final bool disposeOnExitRequest;

  /// An [CobaltAppScope] shaped for [MaterialApp.builder] and its siblings.
  ///
  /// Putting the scope there instead of above the app is what lets [loading]
  /// and [errorBuilder] be ordinary screens: everything `builder` returns sits
  /// below `Theme`, `Directionality`, `MediaQuery` and `Localizations`, and
  /// the `child` it receives is the navigator, so routes still resolve from
  /// the scope.
  ///
  /// ```dart
  /// MaterialApp(
  ///   builder: CobaltAppScope.builder(root: const AppScope()),
  ///   home: const HomeScreen(),
  /// )
  /// ```
  ///
  /// An app that already uses `builder` composes the two by hand rather than
  /// reaching for this — merging two builders is the app's decision, not the
  /// framework's:
  ///
  /// ```dart
  /// builder: (context, child) => CobaltAppScope(
  ///   root: const AppScope(),
  ///   child: MyOwnWrapper(child: child!),
  /// ),
  /// ```
  static TransitionBuilder builder({
    required CobaltScopeBuilder root,
    List<CobaltBootstrapStep> Function()? bootstrap,
    String rootName = 'root',
    List<CobaltObserver> observers = const [],
    List<CobaltOverride<Object>> Function()? overrides,
    List<CobaltKey> warmUp = const [],
    Widget? loading,
    Widget Function(BuildContext context, Object error, VoidCallback retry)?
    errorBuilder,
    bool disposeOnExitRequest = false,
  }) => (BuildContext context, Widget? child) {
    assert(
      child != null,
      'CobaltAppScope.builder needs the app to have routing: it publishes the '
      'scope above the navigator that builder receives. Give the app a home, '
      'routes or a routerConfig, or place CobaltAppScope yourself.',
    );
    return CobaltAppScope(
      root: root,
      bootstrap: bootstrap,
      rootName: rootName,
      observers: observers,
      overrides: overrides,
      warmUp: warmUp,
      loading: loading,
      errorBuilder: errorBuilder,
      disposeOnExitRequest: disposeOnExitRequest,
      child: child!,
    );
  };

  /// The controller of the nearest [CobaltAppScope] above [context].
  static CobaltAppScopeController of(BuildContext context) {
    final controller = context
        .dependOnInheritedWidgetOfExactType<_CobaltAppScopeMarker>()
        ?.controller;
    if (controller == null) {
      throw CobaltNoAppScopeError();
    }
    return controller;
  }

  /// Starts the graph, however this instance was told to describe it.
  Future<CobaltScope> _build() {
    final start = this.start;
    if (start != null) return start();
    return CobaltApplication.start(
      root: root!,
      bootstrap: bootstrap?.call() ?? const [],
      rootName: rootName,
      observers: observers,
      overrides: overrides?.call() ?? const [],
    );
  }

  @override
  State<CobaltAppScope> createState() => _CobaltAppScopeState();
}

class _CobaltAppScopeState extends State<CobaltAppScope>
    implements CobaltAppScopeController {
  CobaltScope? _scope;
  Object? _error;
  AppLifecycleListener? _lifecycle;

  /// Bumped by every start and by teardown, so a slow attempt that lost its
  /// race can tell and release what it built instead of publishing it.
  var _attempt = 0;

  @override
  void initState() {
    super.initState();
    if (widget.disposeOnExitRequest) {
      _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    }
    unawaited(_start());
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    try {
      final scope = await widget._build();
      if (!mounted || attempt != _attempt) {
        await _release(scope, 'a root scope whose CobaltAppScope moved on');
        return;
      }
      setState(() {
        _scope = scope;
        _error = null;
      });
      if (widget.warmUp.isNotEmpty) unawaited(_warm(scope, attempt));
    } catch (error, stackTrace) {
      if (!mounted || attempt != _attempt) {
        _report(
          error,
          stackTrace,
          'starting a root scope, after it was no '
          'longer wanted',
        );
        return;
      }
      setState(() => _error = error);
    }
  }

  Future<void> _warm(CobaltScope scope, int attempt) async {
    try {
      await scope.warmUp(widget.warmUp);
    } catch (error, stackTrace) {
      // A graph that was restarted or unmounted in the meantime fails its
      // builds on purpose; that is not worth a report.
      if (!mounted || attempt != _attempt) return;
      _report(error, stackTrace, 'warming up the root scope of CobaltAppScope');
    }
  }

  @override
  Future<void> restart() async {
    if (!mounted) return;
    final scope = _scope;
    setState(() {
      _scope = null;
      _error = null;
    });
    _attempt++;
    if (scope != null) {
      await _release(scope, 'the root scope owned by CobaltAppScope');
    }
    await _start();
  }

  Future<AppExitResponse> _onExitRequested() async {
    final scope = _scope;
    if (scope == null) return AppExitResponse.exit;
    _attempt++;
    if (mounted) {
      setState(() => _scope = null);
    } else {
      _scope = null;
    }
    await _release(scope, 'the root scope owned by CobaltAppScope, on exit');
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    _attempt++;
    _lifecycle?.dispose();
    _lifecycle = null;
    final scope = _scope;
    _scope = null;
    if (scope != null) {
      unawaited(_release(scope, 'the root scope owned by CobaltAppScope'));
    }
    super.dispose();
  }

  Future<void> _release(CobaltScope scope, String what) async {
    try {
      await scope.dispose();
    } catch (error, stackTrace) {
      _report(error, stackTrace, 'disposing $what');
    }
  }

  void _report(Object error, StackTrace stackTrace, String what) =>
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'cobalt_flutter',
          context: ErrorDescription(what),
        ),
      );

  @override
  Widget build(BuildContext context) =>
      _CobaltAppScopeMarker(controller: this, child: _content(context));

  Widget _content(BuildContext context) {
    final error = _error;
    if (error != null) {
      final errorBuilder = widget.errorBuilder;
      if (errorBuilder != null) {
        return errorBuilder(context, error, () => unawaited(restart()));
      }
      throw error;
    }

    final scope = _scope;
    if (scope == null) return widget.loading ?? const SizedBox.shrink();

    // Keyed by the scope: a child scope cannot be reparented, so a restart has
    // to rebuild the subtree rather than hand it a new root underneath.
    return CobaltScopeProvider(
      key: ValueKey(scope),
      scope: scope,
      child: widget.child,
    );
  }
}

class _CobaltAppScopeMarker extends InheritedWidget {
  const _CobaltAppScopeMarker({required this.controller, required super.child});

  final CobaltAppScopeController controller;

  @override
  bool updateShouldNotify(_CobaltAppScopeMarker oldWidget) => false;
}
