import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:meta/meta.dart';

/// What a cold start spent its time on, collected by
/// `CobaltStartupObserver`.
///
/// [toString] reads as a short summary: the slowest bootstrap step, and the
/// slowest builds with how long each waited for its dependencies.
@immutable
final class CobaltStartupReport {
  /// Creates a report.
  const CobaltStartupReport({
    required this.total,
    this.bootstrap = const [],
    this.builds = const [],
  });

  /// From the start of the first bootstrap step or build to the end of the
  /// last one.
  final Duration total;

  /// Every bootstrap step, in the order it ran.
  final List<({String step, Duration took})> bootstrap;

  /// What the start itself built in the root scope, eager and async
  /// singletons, slowest first.
  ///
  /// [took] includes the dependencies a build waited for, [self] does not, so
  /// `took - self` is the wait.
  final List<({CobaltKey key, Duration took, Duration self})> builds;

  @override
  String toString() {
    final lines = <String>['Startup took ${_duration(total)}.'];
    if (bootstrap.isNotEmpty) {
      final slowest = bootstrap.reduce((a, b) => b.took > a.took ? b : a);
      final spent = bootstrap.fold(Duration.zero, (sum, it) => sum + it.took);
      lines.add(
        'Bootstrap: ${_duration(spent)} in ${bootstrap.length} '
        '${bootstrap.length == 1 ? 'step' : 'steps'}, the slowest '
        '${slowest.step} (${_duration(slowest.took)}).',
      );
    }
    if (builds.isNotEmpty) {
      lines.add('Slowest builds:');
      for (final build in builds.take(5)) {
        final waited = build.took - build.self;
        lines.add(
          '  ${build.key} ${_duration(build.took)}'
          '${waited > Duration.zero ? ', ${_duration(waited)} waiting for its dependencies' : ''}',
        );
      }
    }
    return lines.join('\n');
  }

  static String _duration(Duration took) => took.inMilliseconds >= 1
      ? '${took.inMilliseconds}ms'
      : '${took.inMicroseconds}µs';
}
