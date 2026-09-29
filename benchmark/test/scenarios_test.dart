import 'package:cobalt/cobalt.dart';
import 'package:cobalt_benchmark/cobalt_benchmark.dart';
import 'package:test/test.dart';

void main() {
  group('each container does what the scenario says', () {
    test('a singleton is the same object every time', () {
      final scope = cobaltScope();
      final getIt = getItContainer();
      expect(scope.get<Api>(), same(scope.get<Api>()));
      expect(getIt<Api>(), same(getIt<Api>()));
    });

    test('a transient is new every time, on the same singletons', () {
      final scope = cobaltScope();
      final getIt = getItContainer();
      final (a, b) = (scope.get<Report>(), scope.get<Report>());
      final (c, d) = (getIt<Report>(), getIt<Report>());
      expect(a, isNot(same(b)));
      expect(a.api, same(b.api));
      expect(c, isNot(same(d)));
      expect(c.api, same(d.api));
    });

    test('the graph resolves every node, each onto the one before', () {
      for (final last in [cobaltGraph(), getItGraph()]) {
        var node = last;
        var count = 1;
        while (node.previous != null) {
          expect(node.previous!.index, node.index - 1);
          node = node.previous!;
          count++;
        }
        expect(count, graphSize);
        expect(last.index, graphSize - 1);
      }
    });

    test('the async start builds every service', () async {
      final scope = await cobaltStart();
      final getIt = await getItStart();
      for (var i = 0; i < asyncServices; i++) {
        expect(scope.get<Service>(name: 's$i').index, i);
        expect(getIt<Service>(instanceName: 's$i').index, i);
      }
      await scope.dispose();
    });

    test('the observers see the builds they are measured on', () {
      final seen = <CobaltLogRecord>[];
      cobaltScope(observers: [_Collect(seen)]).get<Report>();
      expect(seen, isNotEmpty);
    });
  });

  test('every scenario measures to a positive time on each side', () async {
    for (final scenario in scenarios) {
      for (final side in [scenario.cobalt, ?scenario.getIt]) {
        final nanos = await nanosPerOp(side, scenario.ops, millis: 1);
        expect(nanos, isPositive, reason: scenario.name);
        expect(nanos.isFinite, isTrue, reason: scenario.name);
      }
    }
  });

  test('times read in the unit that suits them', () {
    expect(formatNanos(4.26), '4.3 ns');
    expect(formatNanos(42.4), '42 ns');
    expect(formatNanos(3140), '3.14 µs');
    expect(formatNanos(314000), '314.0 µs');
    expect(formatNanos(2500000), '2.50 ms');
  });
}

final class _Collect extends CobaltRecordingObserver {
  _Collect(this.seen);
  final List<CobaltLogRecord> seen;

  @override
  void onRecord(CobaltLogRecord record) => seen.add(record);
}
