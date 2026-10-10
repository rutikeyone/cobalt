import 'package:cobalt/src/errors/cobalt_dispose_failure.dart';
import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/logging/cobalt_log_level.dart';
import 'package:cobalt/src/logging/cobalt_log_record.dart';
import 'package:cobalt/src/observer/cobalt_event_kind.dart';
import 'package:cobalt/src/observer/cobalt_observer.dart';
import 'package:cobalt/src/observer/cobalt_scope_ref.dart';
import 'package:cobalt/src/scope/cobalt_registration_kind.dart';

(CobaltKey, Duration)? _lastSelfTime;

/// Turns Cobalt's events into [CobaltLogRecord]s and hands each to [onRecord].
///
/// The wording of every event lives here and only here. Two lenses read the
/// same stream — one writes lines, one collects failures with the events that
/// led to them — and if each carried its own copy of these fourteen mappings the
/// two would drift apart on the first reworded sentence.
///
/// Deliberately stateless, so a subclass that needs no state of its own can
/// still be `const`.
abstract base class CobaltRecordingObserver extends CobaltObserver {
  /// Creates the base.
  const CobaltRecordingObserver();

  /// Receives every event [accepts] lets through, already turned into a
  /// record.
  void onRecord(CobaltLogRecord record);

  /// Whether a record at [level] is wanted at all.
  ///
  /// Asked before the record is made, so an event nobody wants costs no
  /// formatting. `CobaltLogObserver` drops per-instance records by default;
  /// without this, every build would still spell out its message only for it
  /// to be thrown away — which doubled the cost of a build with a log
  /// attached. Every level by default, and [onRecord] never sees a record
  /// this turned down.
  bool accepts(CobaltLogLevel level) => true;

  void _emit(
    CobaltEventKind kind,
    CobaltLogLevel level,
    String Function() message, {
    CobaltScopeRef? scope,
    CobaltKey? key,
    CobaltRegistrationKind? registrationKind,
    bool? retained,
    Duration? took,
    Duration? selfTook,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!accepts(level)) return;
    onRecord(
      CobaltLogRecord(
        kind: kind,
        level: level,
        message: message(),
        scope: scope,
        key: key,
        registrationKind: registrationKind,
        retained: retained,
        took: took,
        selfTook: selfTook,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void onScopePushed(CobaltScopeRef scope) => _emit(
    CobaltEventKind.scopePushed,
    CobaltLogLevel.debug,
    () => 'scope "$scope" pushed',
    scope: scope,
  );

  @override
  void onRegistrationOverridden(CobaltScopeRef scope, CobaltKey key) => _emit(
    CobaltEventKind.registrationOverridden,
    CobaltLogLevel.info,
    () => 'registration of $key in "$scope" replaced by an override',
    scope: scope,
    key: key,
  );

  @override
  void onScopeInitStarted(CobaltScopeRef scope, int levels) => _emit(
    CobaltEventKind.scopeInitStarted,
    CobaltLogLevel.debug,
    () => 'scope "$scope" initializing, $levels level(s)',
    scope: scope,
  );

  @override
  void onScopeInitCompleted(CobaltScopeRef scope, Duration took) => _emit(
    CobaltEventKind.scopeInitCompleted,
    CobaltLogLevel.info,
    () => 'scope "$scope" ready in ${took.inMilliseconds}ms',
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
    () => 'scope "$scope" failed to initialize',
    scope: scope,
    error: error,
    stackTrace: stackTrace,
  );

  /// The creation record is written from [onInstanceBuilt], which follows
  /// this for the same build and also knows how long it took — one record per
  /// build, as before, now with its time.
  @override
  void onInstanceCreated(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
  }) {}

  /// Held for the [onInstanceBuilt] that follows it for the same build.
  @override
  void onInstanceSelfTime(CobaltScopeRef scope, CobaltKey key, Duration self) {
    _lastSelfTime = (key, self);
  }

  @override
  void onInstanceBuilt(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
    required Duration took,
  }) {
    final last = _lastSelfTime;
    final selfTook = last != null && last.$1 == key ? last.$2 : null;
    _emitBuilt(scope, key, kind, retained, took, selfTook);
  }

  void _emitBuilt(
    CobaltScopeRef scope,
    CobaltKey key,
    CobaltRegistrationKind kind,
    bool retained,
    Duration took,
    Duration? selfTook,
  ) => _emit(
    CobaltEventKind.instanceCreated,
    CobaltLogLevel.trace,
    () => retained
        ? 'built $key in "$scope" as ${kind.name} in ${_duration(took)}'
        : 'built $key in "$scope" as ${kind.name}, not retained, in '
              '${_duration(took)}',
    scope: scope,
    key: key,
    registrationKind: kind,
    retained: retained,
    took: took,
    selfTook: selfTook,
  );

  /// Milliseconds, or microseconds below one — most builds are.
  static String _duration(Duration took) => took.inMilliseconds >= 1
      ? '${took.inMilliseconds}ms'
      : '${took.inMicroseconds}µs';

  @override
  void onInstanceDisposed(CobaltScopeRef scope, String label) => _emit(
    CobaltEventKind.instanceDisposed,
    CobaltLogLevel.trace,
    () => 'released $label in "$scope"',
    scope: scope,
  );

  @override
  void onScopeDisposeStarted(CobaltScopeRef scope) => _emit(
    CobaltEventKind.scopeDisposeStarted,
    CobaltLogLevel.debug,
    () => 'scope "$scope" disposing',
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
        () => 'scope "$scope" disposed in ${took.inMilliseconds}ms',
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
        () => 'scope "$scope" could not release ${failure.label}',
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
    () => 'bootstrap "$step" started',
  );

  @override
  void onBootstrapStepCompleted(String step, Duration took) => _emit(
    CobaltEventKind.bootstrapStepCompleted,
    CobaltLogLevel.info,
    () => 'bootstrap "$step" done in ${took.inMilliseconds}ms',
  );

  @override
  void onBootstrapStepFailed(
    String step,
    Object error,
    StackTrace stackTrace,
  ) => _emit(
    CobaltEventKind.bootstrapStepFailed,
    CobaltLogLevel.error,
    () => 'bootstrap "$step" failed',
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
    () => 'bootstrap "$step" could not be released while rolling startup back',
    error: error,
    stackTrace: stackTrace,
  );
}
