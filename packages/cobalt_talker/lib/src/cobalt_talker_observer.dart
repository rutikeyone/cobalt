import 'package:cobalt/cobalt.dart';
import 'package:cobalt_talker/src/cobalt_talker_logs.dart';
import 'package:talker/talker.dart';

/// Reports Cobalt's events to talker as typed logs.
///
/// This is an [CobaltObserver] rather than an `CobaltLogSink`, which is the
/// whole point of using talker: each kind of event becomes its own
/// [TalkerLog] with a title and a colour, so `TalkerScreen` can filter them
/// apart. A sink would flatten everything into one stream of strings.
///
/// ```dart
/// final talker = Talker();
/// final scope = await CobaltApplication.start(
///   root: const AppScope(),
///   observers: [CobaltTalkerObserver(talker)],
/// );
/// ```
///
/// Set [verbose] to see every instance the graph builds. It is off by default
/// because a real graph builds a great many, and the useful signal — scopes
/// appearing, startup finishing, things failing — drowns in it.
final class CobaltTalkerObserver extends CobaltObserver {
  /// Reports to [talker].
  const CobaltTalkerObserver(this.talker, {this.verbose = false});

  /// Where logs go.
  final Talker talker;

  /// Whether per-instance logs are emitted.
  final bool verbose;

  @override
  void onScopePushed(CobaltScopeRef scope) =>
      talker.logCustom(CobaltScopeLog('scope "$scope" pushed'));

  @override
  void onRegistrationOverridden(CobaltScopeRef scope, CobaltKey key) =>
      talker.logCustom(
        CobaltScopeLog(
          'registration of $key in "$scope" replaced by an override',
        ),
      );

  @override
  void onScopeInitStarted(CobaltScopeRef scope, int levels) => talker.logCustom(
    CobaltStartupLog(
      'scope "$scope" initializing, $levels level(s)',
      logLevel: LogLevel.debug,
    ),
  );

  @override
  void onScopeInitCompleted(CobaltScopeRef scope, Duration took) =>
      talker.logCustom(
        CobaltStartupLog('scope "$scope" ready in ${took.inMilliseconds}ms'),
      );

  @override
  void onScopeInitFailed(
    CobaltScopeRef scope,
    Object error,
    StackTrace stackTrace,
  ) => talker.logCustom(
    CobaltFailureLog(
      'scope "$scope" failed to initialize',
      exception: error,
      stackTrace: stackTrace,
    ),
  );

  @override
  void onInstanceCreated(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
  }) {
    if (!verbose) return;
    talker.logCustom(
      CobaltInstanceLog(
        retained
            ? 'built $key in "$scope" as ${kind.name}'
            : 'built $key in "$scope" as ${kind.name} (loose)',
      ),
    );
  }

  @override
  void onInstanceDisposed(CobaltScopeRef scope, String label) {
    if (!verbose) return;
    talker.logCustom(CobaltInstanceLog('released $label in "$scope"'));
  }

  @override
  void onScopeDisposeStarted(CobaltScopeRef scope) =>
      talker.logCustom(CobaltScopeLog('scope "$scope" disposing'));

  @override
  void onScopeDisposed(
    CobaltScopeRef scope,
    Duration took,
    List<CobaltDisposeFailure> failures,
  ) {
    if (failures.isEmpty) {
      talker.logCustom(
        CobaltScopeLog('scope "$scope" disposed in ${took.inMilliseconds}ms'),
      );
      return;
    }
    for (final failure in failures) {
      talker.logCustom(
        CobaltFailureLog(
          'scope "$scope" could not release ${failure.label}',
          exception: failure.error,
          stackTrace: failure.stackTrace,
          logLevel: LogLevel.warning,
        ),
      );
    }
  }

  @override
  void onBootstrapStepStarted(String step) => talker.logCustom(
    CobaltStartupLog('bootstrap "$step" started', logLevel: LogLevel.debug),
  );

  @override
  void onBootstrapStepCompleted(String step, Duration took) => talker.logCustom(
    CobaltStartupLog('bootstrap "$step" done in ${took.inMilliseconds}ms'),
  );

  @override
  void onBootstrapStepFailed(
    String step,
    Object error,
    StackTrace stackTrace,
  ) => talker.logCustom(
    CobaltFailureLog(
      'bootstrap "$step" failed',
      exception: error,
      stackTrace: stackTrace,
    ),
  );

  @override
  void onBootstrapStepReleaseFailed(
    String step,
    Object error,
    StackTrace stackTrace,
  ) => talker.logCustom(
    CobaltFailureLog(
      'bootstrap "$step" could not be released while rolling startup back',
      exception: error,
      stackTrace: stackTrace,
      logLevel: LogLevel.warning,
    ),
  );
}
