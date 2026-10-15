import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/logging/cobalt_startup_report.dart';
import 'package:cobalt/src/observer/cobalt_observer.dart';
import 'package:cobalt/src/observer/cobalt_scope_ref.dart';
import 'package:cobalt/src/scope/cobalt_registration_kind.dart';

/// Collects what a cold start spends its time on, for [report].
///
/// Pass it with the other observers and read [report] once the start has
/// returned:
///
/// ```dart
/// final startup = CobaltStartupObserver();
/// final app = await CobaltApplication.start(
///   root: const CobaltRoot(),
///   observers: [startup],
/// );
/// print(startup.report);
/// ```
///
/// It records the bootstrap steps and what the start builds in the root
/// scope: eager singletons and the async singletons `init()` waits for. A
/// lazy singleton built along the way is part of the build that asked for
/// it; one built later, by a screen, is not part of the start. A restart
/// starts the report over.
final class CobaltStartupObserver extends CobaltObserver {
  /// Creates an observer with an empty report.
  CobaltStartupObserver();

  final _clock = Stopwatch()..start();
  final _bootstrap = <({String step, Duration took})>[];
  final _builds = <({CobaltKey key, Duration took, Duration self})>[];
  final _built = <CobaltKey>{};
  final _selfTimes = <CobaltKey, Duration>{};
  Duration? _first;
  Duration? _last;

  /// What has been recorded so far: the whole start once it has returned.
  CobaltStartupReport get report {
    final builds = [..._builds]..sort((a, b) => b.took.compareTo(a.took));
    return CobaltStartupReport(
      total: _first == null ? Duration.zero : _last! - _first!,
      bootstrap: List.unmodifiable(_bootstrap),
      builds: List.unmodifiable(builds),
    );
  }

  void _span(Duration took) {
    final end = _clock.elapsed;
    final start = end - took;
    if (_first == null || start < _first!) _first = start;
    if (_last == null || end > _last!) _last = end;
  }

  void _reset() {
    _bootstrap.clear();
    _builds.clear();
    _built.clear();
    _selfTimes.clear();
    _first = null;
    _last = null;
  }

  @override
  void onBootstrapStepStarted(String step) {
    if (_builds.isNotEmpty) _reset();
  }

  @override
  void onBootstrapStepCompleted(String step, Duration took) {
    _bootstrap.add((step: step, took: took));
    _span(took);
  }

  @override
  void onInstanceSelfTime(CobaltScopeRef scope, CobaltKey key, Duration self) {
    if (scope.depth == 0) _selfTimes[key] = self;
  }

  @override
  void onInstanceBuilt(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
    required Duration took,
  }) {
    final self = _selfTimes.remove(key) ?? took;
    if (scope.depth != 0) return;
    if (kind != CobaltRegistrationKind.singleton &&
        kind != CobaltRegistrationKind.asyncSingleton) {
      return;
    }
    if (!_built.add(key)) {
      _reset();
      _built.add(key);
    }
    _builds.add((key: key, took: took, self: self));
    _span(took);
  }
}
