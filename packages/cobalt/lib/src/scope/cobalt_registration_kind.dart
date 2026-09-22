/// What kind of registration a key has.
///
/// Reported by `CobaltScope.debugKindOf` so a tool can tell what it is looking
/// at without reaching for the registration itself, which stays internal — a
/// registration carries factories and mutable build state, and handing those
/// out would make every diagnostic a way to corrupt the graph.
///
/// The distinction that matters most in practice is [parameterized]: it is the
/// one kind that cannot be resolved without a value from the caller, so a tool
/// walking a graph has to report it as unchecked rather than as broken.
enum CobaltRegistrationKind {
  /// An instance registered directly, already built.
  singleton,

  /// Built on first resolution and reused, retained by the scope.
  lazySingleton,

  /// Built fresh on every resolution and not retained.
  transient,

  /// Built during `init()`, retained by the scope.
  asyncSingleton,

  /// Built by the first `getAsync`, retained by the scope.
  lazyAsyncSingleton,

  /// Built from a value the caller passes to `getWithParam`, not retained.
  parameterized,
}
