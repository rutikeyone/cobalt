import 'package:cobalt_benchmark/cobalt_benchmark.dart';

/// Prints one row per scenario: Cobalt, get_it, and Cobalt's time as a
/// multiple of get_it's.
///
/// `--quick` measures for a moment instead of two seconds a side — enough to
/// see that everything runs, not enough to believe the numbers.
Future<void> main(List<String> args) async {
  final millis = args.contains('--quick') ? 20 : 2000;

  print(
    '${'scenario'.padRight(44)}${'cobalt'.padLeft(12)}'
    '${'get_it'.padLeft(12)}${'cobalt/get_it'.padLeft(16)}',
  );
  for (final scenario in scenarios) {
    final cobalt = await nanosPerOp(
      scenario.cobalt,
      scenario.ops,
      millis: millis,
    );
    final getIt = scenario.getIt == null
        ? null
        : await nanosPerOp(scenario.getIt!, scenario.ops, millis: millis);
    print(
      '${scenario.name.padRight(44)}${formatNanos(cobalt).padLeft(12)}'
      '${(getIt == null ? '—' : formatNanos(getIt)).padLeft(12)}'
      '${(getIt == null ? '—' : '${(cobalt / getIt).toStringAsFixed(2)}×').padLeft(16)}',
    );
  }
}
