import 'package:cobalt/cobalt.dart';
import 'package:cobalt_benchmark/src/graph.dart';
import 'package:cobalt_benchmark/src/scenario.dart';

/// A sink for results, so the compiler cannot drop the work that made them.
Object? blackhole;

/// Everything `bin/main.dart` reports, in the order it reports it.
final scenarios = <Scenario>[
  Scenario(
    'get a built singleton',
    ops: 1000,
    cobalt: SyncSide(() {
      final scope = cobaltScope()..get<Config>();
      return () {
        for (var i = 0; i < 1000; i++) {
          blackhole = scope.get<Config>();
        }
      };
    }),
    getIt: SyncSide(() {
      final getIt = getItContainer()..get<Config>();
      return () {
        for (var i = 0; i < 1000; i++) {
          blackhole = getIt<Config>();
        }
      };
    }),
  ),
  Scenario(
    'build a transient with two dependencies',
    ops: 1000,
    cobalt: _buildReports(cobaltScope),
    getIt: SyncSide(() {
      final getIt = getItContainer()..get<Report>();
      return () {
        for (var i = 0; i < 1000; i++) {
          blackhole = getIt<Report>();
        }
      };
    }),
  ),
  Scenario(
    'register $graphSize, then get each once',
    cobalt: SyncSide(
      () =>
          () => blackhole = cobaltGraph(),
    ),
    getIt: SyncSide(
      () =>
          () => blackhole = getItGraph(),
    ),
  ),
  Scenario(
    'start $asyncServices async singletons',
    cobalt: AsyncSide(
      () =>
          () async => blackhole = await cobaltStart(),
    ),
    getIt: AsyncSide(
      () =>
          () async => blackhole = await getItStart(),
    ),
  ),
  Scenario(
    'the transient, with an empty observer',
    ops: 1000,
    cobalt: _buildReports(
      () => cobaltScope(observers: const [EmptyObserver()]),
    ),
  ),
  Scenario(
    'the transient, with a recording observer',
    ops: 1000,
    cobalt: _buildReports(
      () => cobaltScope(observers: const [DiscardingObserver()]),
    ),
  ),
];

/// Resolves [Report] — built anew each time — from the scope [scopeOf] makes.
SyncSide _buildReports(CobaltScope Function() scopeOf) => SyncSide(() {
  final scope = scopeOf()..get<Report>();
  return () {
    for (var i = 0; i < 1000; i++) {
      blackhole = scope.get<Report>();
    }
  };
});
