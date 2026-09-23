import 'package:cobalt_flutter/cobalt_flutter.dart';

/// The four things an Cobalt event can be about.
///
/// Fourteen kinds is too many to give a colour each, and colouring by level
/// says how loud an event is rather than what it concerns. These four are the
/// division `CobaltTalkerObserver` already makes when it picks a log type, and
/// keeping them the same is what lets one palette dress both screens.
enum CobaltInspectorFamily {
  /// A scope appeared or went away.
  scope,

  /// Startup: bootstrap steps and async initialization.
  startup,

  /// An instance was built or released.
  instance,

  /// Something failed.
  failure;

  /// Which family [kind] belongs to.
  static CobaltInspectorFamily of(CobaltEventKind kind) => switch (kind) {
    CobaltEventKind.scopePushed ||
    CobaltEventKind.registrationOverridden ||
    CobaltEventKind.scopeDisposeStarted ||
    CobaltEventKind.scopeDisposed => CobaltInspectorFamily.scope,
    CobaltEventKind.scopeInitStarted ||
    CobaltEventKind.scopeInitCompleted ||
    CobaltEventKind.bootstrapStepStarted ||
    CobaltEventKind.bootstrapStepCompleted => CobaltInspectorFamily.startup,
    CobaltEventKind.instanceCreated ||
    CobaltEventKind.instanceDisposed => CobaltInspectorFamily.instance,
    CobaltEventKind.scopeInitFailed ||
    CobaltEventKind.scopeDisposeFailed ||
    CobaltEventKind.bootstrapStepFailed ||
    CobaltEventKind.bootstrapStepReleaseFailed => CobaltInspectorFamily.failure,
  };

  /// The title `cobalt_talker` files this family under.
  ///
  /// `TalkerScreenTheme` colours by title, so this is the whole of the bridge
  /// between a palette here and a themed talker screen.
  String get talkerTitle => switch (this) {
    CobaltInspectorFamily.scope => 'cobalt-scope',
    CobaltInspectorFamily.startup => 'cobalt-startup',
    CobaltInspectorFamily.instance => 'cobalt-instance',
    CobaltInspectorFamily.failure => 'cobalt-failure',
  };
}
