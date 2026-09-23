import 'package:cobalt/src/errors/cobalt_dispose_failure.dart';
import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/logging/cobalt_log_level.dart';
import 'package:cobalt/src/logging/cobalt_log_record.dart';
import 'package:cobalt/src/observer/cobalt_event_kind.dart';
import 'package:cobalt/src/observer/cobalt_observer.dart';
import 'package:cobalt/src/observer/cobalt_scope_ref.dart';
import 'package:cobalt/src/scope/cobalt_registration_kind.dart';

/// Turns Cobalt's events into [CobaltLogRecord]s and hands each to [onRecord].
///
/// The wording of every event lives here and only here. Two lenses read the
/// same stream — one writes lines, one collects failures with the events that
/// led to them — and if each carried its own copy of these twelve mappings the
/// two would drift apart on the first reworded sentence.
///
/// Deliberately stateless, so a subclass that needs no state of its own can
/// still be `const`.
abstract base class CobaltRecordingObserver extends CobaltObserver {
  /// Creates the base.
  const CobaltRecordingObserver();

  /// Receives every event, already turned into a record.
  void onRecord(CobaltLogRecord record);

  void _emit(
    CobaltEventKind kind,
    CobaltLogLevel level,
    String message, {
    CobaltScopeRef? scope,
    CobaltKey? key,
    CobaltRegistrationKind? registrationKind,
    bool? retained,
    Object? error,
    StackTrace? stackTrace,
  }) => onRecord(
    CobaltLogRecord(
      kind: kind,
      level: level,
      message: message,
      scope: scope,
      key: key,
      registrationKind: registrationKind,
      retained: retained,
      error: error,
      stackTrace: stackTrace,
    ),
  );

  @override
  void onScopePushed(CobaltScopeRef scope) => _emit(
    CobaltEventKind.scopePushed,
    CobaltLogLevel.debug,
    'scope "$scope" pushed',
    scope: scope,
  );

  @override
  void onRegistrationOverridden(CobaltScopeRef scope, CobaltKey key) => _emit(
    CobaltEventKind.registrationOverridden,
    CobaltLogLevel.info,
    'registration of $key in "$scope" replaced by an override',
    scope: scope,
    key: key,
  );

  @override
  void onScopeInitStarted(CobaltScopeRef scope, int levels) => _emit(
    CobaltEventKind.scopeInitStarted,
    CobaltLogLevel.debug,
    'scope "$scope" initializing, $levels level(s)',
    scope: scope,
  );

  @override
  void onScopeInitCompleted(CobaltScopeRef scope, Duration took) => _emit(
    CobaltEventKind.scopeInitCompleted,
    CobaltLogLevel.info,
    'scope "$scope" ready in ${took.inMilliseconds}ms',
    scope: scope,
  );

  @override
  void onScopeInitFailed(
    CobaltScopeRef scope,
    Object error,
    StackTrace stackTrace,
  ) => _emit(
    CobaltEventKind.scopeInitFailed,
    CobaltLogLevel.error,
    'scope "$scope" failed to initialize',
    scope: scope,
    error: error,
    stackTrace: stackTrace,
  );

  @override
  void onInstanceCreated(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
  }) => _emit(
    CobaltEventKind.instanceCreated,
    CobaltLogLevel.trace,
    retained
        ? 'built $key in "$scope" as ${kind.name}'
        : 'built $key in "$scope" as ${kind.name}, not retained',
    scope: scope,
    key: key,
    registrationKind: kind,
    retained: retained,
  );

  @override
  void onInstanceDisposed(CobaltScopeRef scope, String label) => _emit(
    CobaltEventKind.instanceDisposed,
    CobaltLogLevel.trace,
    'released $label in "$scope"',
    scope: scope,
  );

  @override
  void onScopeDisposeStarted(CobaltScopeRef scope) => _emit(
    CobaltEventKind.scopeDisposeStarted,
    CobaltLogLevel.debug,
    'scope "$scope" disposing',
    scope: scope,
  );

  @override
  void onScopeDisposed(
    CobaltScopeRef scope,
    Duration took,
    List<CobaltDisposeFailure> failures,
  ) {
    if (failures.isEmpty) {
      _emit(
        CobaltEventKind.scopeDisposed,
        CobaltLogLevel.debug,
        'scope "$scope" disposed in ${took.inMilliseconds}ms',
        scope: scope,
      );
      return;
    }
    // One record per failure, not one for the lot: each carries its own error
    // and stack trace, and a destination that groups by exception would
    // otherwise see them merged into a single unrelated blob.
    for (final failure in failures) {
      _emit(
        CobaltEventKind.scopeDisposeFailed,
        CobaltLogLevel.warning,
        'scope "$scope" could not release ${failure.label}',
        scope: scope,
        error: failure.error,
        stackTrace: failure.stackTrace,
      );
    }
  }

  @override
  void onBootstrapStepStarted(String step) => _emit(
    CobaltEventKind.bootstrapStepStarted,
    CobaltLogLevel.debug,
    'bootstrap "$step" started',
  );

  @override
  void onBootstrapStepCompleted(String step, Duration took) => _emit(
    CobaltEventKind.bootstrapStepCompleted,
    CobaltLogLevel.info,
    'bootstrap "$step" done in ${took.inMilliseconds}ms',
  );

  @override
  void onBootstrapStepFailed(
    String step,
    Object error,
    StackTrace stackTrace,
  ) => _emit(
    CobaltEventKind.bootstrapStepFailed,
    CobaltLogLevel.error,
    'bootstrap "$step" failed',
    error: error,
    stackTrace: stackTrace,
  );

  @override
  void onBootstrapStepReleaseFailed(
    String step,
    Object error,
    StackTrace stackTrace,
  ) => _emit(
    CobaltEventKind.bootstrapStepReleaseFailed,
    CobaltLogLevel.warning,
    'bootstrap "$step" could not be released while rolling startup back',
    error: error,
    stackTrace: stackTrace,
  );
}
