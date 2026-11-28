/// Where a scope is in its lifecycle.
enum CobaltScopeState {
  /// Accepting registrations; async singletons have not been built yet.
  open,

  /// `init()` is running. Registrations and resolutions still work, so a
  /// factory can resolve during initialization.
  initializing,

  /// Fully built. Every async singleton is ready to resolve.
  active,

  failed,

  /// Teardown has begun. Any further use throws `CobaltScopeStateError`.
  disposing,

  /// Torn down and detached from its parent. Permanently unusable.
  disposed,
}
