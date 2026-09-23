/// What happened, as a value rather than as prose.
///
/// A record carries its message already formatted, which is what a console
/// wants and what a structured destination cannot use: keying on
/// `event=scopeInitFailed` beats matching the sentence
/// `scope "app" failed to initialize`, which is free to be reworded.
///
/// One value per [CobaltObserver] callback, so a sink can switch over the whole
/// set and the compiler will say when a new event arrives.
enum CobaltEventKind {
  scopePushed,
  registrationOverridden,
  scopeInitStarted,
  scopeInitCompleted,
  scopeInitFailed,
  instanceCreated,
  instanceDisposed,
  scopeDisposeStarted,
  scopeDisposed,
  scopeDisposeFailed,
  bootstrapStepStarted,
  bootstrapStepCompleted,
  bootstrapStepFailed,
  bootstrapStepReleaseFailed,
}
