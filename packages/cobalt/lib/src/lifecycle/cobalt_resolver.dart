/// Reads instances out of a scope.
///
/// A scope is one, and it is what factories receive, so a factory can
/// resolve its own dependencies without holding a reference to the container.
///
/// A `base` class, so nothing outside Cobalt can implement it — `CobaltScope`
/// is the only resolver. That is what lets a new way of resolving arrive in a
/// minor release: every new method of an interface breaks whoever implemented
/// it, `getAsyncWithParam` among them. It also means a resolver cannot be
/// mocked; a test builds a real scope instead — `cobaltTestRoot` in
/// `cobalt_test` — and registers the doubles it needs.
abstract base class CobaltResolver {
  /// For `CobaltScope`, the one subclass.
  const CobaltResolver();

  /// Returns the instance registered for [T].
  ///
  /// Resolution starts in this scope and walks up through its ancestors, so a
  /// child can see everything its parents registered and can shadow any of it.
  /// It never walks downwards — a parent cannot reach a child's registrations.
  ///
  /// Throws `CobaltNotRegisteredError` if nothing matches, and
  /// `CobaltNotReadyError` for an async singleton requested before `init()`.
  /// A dependency cycle throws `CobaltCycleError` naming the path.
  T get<T extends Object>({String? name});

  /// Returns every registration of [T] visible from this scope, nearest first.
  ///
  /// Registrations are keyed by type *and* name, so this collects the unnamed
  /// one together with all named ones. When a child re-registers the same key
  /// as an ancestor, only the child's instance appears.
  List<T> getAll<T extends Object>();

  /// Builds an instance from a parameterized factory, passing [param] to it.
  ///
  /// The result is never retained by the scope; the caller owns it. Throws
  /// `CobaltError` if the registration is not a parameterized factory.
  T getWithParam<T extends Object, P extends Object>(P param, {String? name});

  /// Returns the instance registered for [T], or null when nothing is.
  ///
  /// This is what an optional dependency reads. A `Foo?` parameter or
  /// `@injected` field resolves through here, so a graph that does not supply
  /// `Foo` injects null instead of failing.
  ///
  /// Null means exactly one thing: nothing is registered under this key.
  /// Everything else still throws — an async singleton requested before
  /// `init()` raises `CobaltNotReadyError`, a parameterized factory raises
  /// `CobaltError`, and a cycle raises `CobaltCycleError`. Folding those into
  /// null would turn a startup-ordering bug into a value that reads as
  /// "absent".
  T? getOrNull<T extends Object>({String? name});

  /// Whether [T] can be resolved from this scope or any ancestor.
  bool isRegistered<T extends Object>({String? name});

  /// Returns the instance registered for [T], building it first if it is a
  /// lazy async registration nobody has asked for yet, or building a new one
  /// if it is an async transient.
  ///
  /// Every other kind resolves as [get] would. The one other difference is an
  /// async singleton that `init()` is still building: this waits for `init()`
  /// instead of throwing `CobaltNotReadyError` — unless it is called from
  /// inside that same `init()`, where waiting could never end, and it throws as
  /// [get] does.
  ///
  /// Concurrent calls for the same key share one build. A build that fails is
  /// not remembered: every caller waiting on it gets the error, and the next
  /// call tries again. A lazy build that asks, through its own chain, for the
  /// key it is building throws `CobaltCycleError` naming the path. An async
  /// transient is never shared: every call builds its own instance, which the
  /// caller owns.
  Future<T> getAsync<T extends Object>({String? name});

  /// [getAll], building any lazy async registration of [T] that is not built
  /// yet and a new instance of any async transient, in the same order.
  Future<List<T>> getAllAsync<T extends Object>();

  /// Builds an instance from an async parameterized factory, passing [param]
  /// to it, and waits for it.
  ///
  /// Every call builds a new instance; the scope never retains it, and the
  /// caller owns it. A synchronous parameterized registration resolves here
  /// too, as [getWithParam] would. Throws `CobaltNotParameterizedError` for a
  /// registration that takes no parameter, `CobaltParamTypeError` when [param]
  /// is not what the factory takes, and `CobaltCycleError` when the build asks,
  /// through its own chain, for the key it is building.
  Future<T> getAsyncWithParam<T extends Object, P extends Object>(
    P param, {
    String? name,
  });
}
