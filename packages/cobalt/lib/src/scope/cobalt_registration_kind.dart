/// What kind of registration a key has.
///
/// Reported by `CobaltScope.registrationOf` so a tool can tell what it is
/// looking at without reaching for the registration itself, which stays
/// internal — a registration carries factories and mutable build state, and
/// handing those out would make every diagnostic a way to corrupt the graph.
///
/// The distinction that matters most in practice is [parameterized] and
/// [asyncParameterized]: they are the kinds that cannot be resolved without a
/// value from the caller, so a tool
/// walking a graph has to report it as unchecked rather than as broken.
///
/// **Ask the getters rather than switching over the values.** New kinds have
/// been added in minor releases and will be again — adding one is a minor
/// change — so an exhaustive `switch` breaks on upgrade, while [isRetained],
/// [takesParam], [isAsync] and [isBuiltByInit] answer the questions a tool
/// actually has for every kind, including ones that do not exist yet.
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

  /// Built asynchronously from a value the caller passes to
  /// `getAsyncWithParam`, not retained.
  asyncParameterized,

  /// Built asynchronously by every `getAsync`, not retained.
  asyncTransient;

  /// Whether the scope keeps what it builds and disposes it with itself.
  ///
  /// False means every resolution builds a new instance that the caller owns
  /// and closes.
  bool get isRetained => switch (this) {
    singleton || lazySingleton || asyncSingleton || lazyAsyncSingleton => true,
    transient || parameterized || asyncParameterized || asyncTransient => false,
  };

  /// Whether resolving it needs a value from the caller — `getWithParam` or
  /// `getAsyncWithParam` — so it cannot be built by walking the graph alone.
  bool get takesParam => switch (this) {
    parameterized || asyncParameterized => true,
    singleton ||
    lazySingleton ||
    transient ||
    asyncSingleton ||
    lazyAsyncSingleton ||
    asyncTransient => false,
  };

  /// Whether its factory is asynchronous, so building it is awaited.
  bool get isAsync => switch (this) {
    asyncSingleton ||
    lazyAsyncSingleton ||
    asyncParameterized ||
    asyncTransient => true,
    singleton || lazySingleton || transient || parameterized => false,
  };

  /// Whether `init()` builds it, in phase 1, rather than the first — or
  /// every — resolution.
  bool get isBuiltByInit => this == asyncSingleton;
}
