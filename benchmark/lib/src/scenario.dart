import 'package:benchmark_harness/benchmark_harness.dart';

/// One container's way of doing a scenario.
///
/// [prepare] does the unmeasured setup and hands back the measured part, which
/// performs the scenario's operations once each time it is called.
sealed class Side {
  const Side();
}

final class SyncSide extends Side {
  const SyncSide(this.prepare);
  final void Function() Function() prepare;
}

final class AsyncSide extends Side {
  const AsyncSide(this.prepare);
  final Future<void> Function() Function() prepare;
}

/// Something measured in Cobalt and, where it has one, in get_it.
final class Scenario {
  const Scenario(this.name, {required this.cobalt, this.getIt, this.ops = 1});

  final String name;
  final Side cobalt;

  /// `null` where get_it has nothing to compare — observers.
  final Side? getIt;

  /// How many operations one call of the measured part performs. Cheap ones
  /// are batched so the timer's own cost does not swamp them.
  final int ops;
}

/// Measures [side] for about [millis] after a short warm-up, in nanoseconds
/// per operation.
///
/// The timing loop is benchmark_harness's own `measureFor`: it runs the
/// measured part until [millis] have passed and divides.
Future<double> nanosPerOp(Side side, int ops, {required int millis}) async {
  final warmUp = millis ~/ 20 + 1;
  final double micros;
  switch (side) {
    case SyncSide(:final prepare):
      final run = prepare();
      BenchmarkBase.measureFor(run, warmUp);
      micros = BenchmarkBase.measureFor(run, millis);
    case AsyncSide(:final prepare):
      final run = prepare();
      await AsyncBenchmarkBase.measureFor(run, warmUp);
      micros = await AsyncBenchmarkBase.measureFor(run, millis);
  }
  return micros * 1000 / ops;
}
