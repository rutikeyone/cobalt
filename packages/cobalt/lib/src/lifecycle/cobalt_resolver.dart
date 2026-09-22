/// Reads instances out of a scope.
///
/// A scope implements this, and it is what factories receive, so a factory can
/// resolve its own dependencies without holding a reference to the container.
abstract interface class CobaltResolver {
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
  /// lazy async registration nobody has asked for yet.
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
  /// key it is building throws `CobaltCycleError` naming the path.
  Future<T> getAsync<T extends Object>({String? name});

  /// [getAll], building any lazy async registration of [T] that is not built
  /// yet, in the same order.
  Future<List<T>> getAllAsync<T extends Object>();
}
