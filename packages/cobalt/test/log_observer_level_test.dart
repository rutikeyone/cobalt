import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class _Collecting implements CobaltLogSink {
  final records = <CobaltLogRecord>[];

  @override
  void write(CobaltLogRecord record) => records.add(record);
}

class Marker {}

final class _Fn implements CobaltFactory<Marker> {
  const _Fn();

  @override
  Marker create(CobaltResolver resolver) => Marker();
}

void main() {
  /// `minimumLevel` is a documented parameter of the observer people are told
  /// to reach for first, and a mutation that ignored it passed every test in
  /// this package. These pin it.
  group('the level a log observer keeps', () {
    test('drops anything quieter than the minimum', () {
      final sink = _Collecting();
      final scope = cobaltTestRoot(
        name: 'app',
        observers: [
          CobaltLogObserver(sink, minimumLevel: CobaltLogLevel.warning),
        ],
      )..registerLazySingleton<Marker>(const _Fn());

      scope
        ..push('session')
        ..get<Marker>();

      expect(
        sink.records,
        isEmpty,
        reason: 'a push is debug and an instance is trace; both are quieter',
      );
    });

    test('keeps what sits at the minimum', () {
      final sink = _Collecting();
      final scope = cobaltTestRoot(
        name: 'app',
        observers: [
          CobaltLogObserver(sink, minimumLevel: CobaltLogLevel.debug),
        ],
      );

      scope.push('session');

      expect(sink.records.map((record) => record.kind), [
        CobaltEventKind.scopePushed,
      ]);
    });

    test('the default keeps per-instance records out', () {
      final sink = _Collecting();
      final scope = cobaltTestRoot(
        name: 'app',
        observers: [CobaltLogObserver(sink)],
      )..registerLazySingleton<Marker>(const _Fn());

      scope.get<Marker>();

      expect(
        sink.records.where(
          (record) => record.kind == CobaltEventKind.instanceCreated,
        ),
        isEmpty,
        reason:
            'the documented reason for the default: a large graph builds '
            'a great many of them',
      );
    });

    test('trace lets everything through', () {
      final sink = _Collecting();
      final scope = cobaltTestRoot(
        name: 'app',
        observers: [
          CobaltLogObserver(sink, minimumLevel: CobaltLogLevel.trace),
        ],
      )..registerLazySingleton<Marker>(const _Fn());

      scope.get<Marker>();

      expect(
        sink.records.map((record) => record.kind),
        contains(CobaltEventKind.instanceCreated),
      );
    });

    test('its accepts answers exactly the levels it keeps', () {
      for (final minimum in CobaltLogLevel.values) {
        final observer = CobaltLogObserver(
          _Collecting(),
          minimumLevel: minimum,
        );
        expect(
          CobaltLogLevel.values.where(observer.accepts),
          CobaltLogLevel.values.skip(minimum.index),
          reason: 'minimum $minimum',
        );
      }
    });
  });

  /// `accepts` exists so a record nobody wants is never made — its message
  /// is never formatted. The benchmark shows the cost; these pin the contract.
  group('what a recording observer accepts', () {
    test('is asked with every event, and onRecord sees only what it took', () {
      final observer = _Picky({CobaltLogLevel.info});
      final scope = cobaltTestRoot(name: 'app', observers: [observer])
        ..registerLazySingleton<Marker>(const _Fn());

      scope
        ..push('session')
        ..get<Marker>();

      expect(
        observer.asked,
        containsAll([CobaltLogLevel.debug, CobaltLogLevel.trace]),
      );
      expect(
        observer.records,
        everyElement(
          isA<CobaltLogRecord>().having(
            (r) => r.level,
            'level',
            CobaltLogLevel.info,
          ),
        ),
      );
      expect(
        observer.records.map((record) => record.kind),
        isNot(contains(CobaltEventKind.instanceCreated)),
      );
    });

    test('is every level unless a subclass says otherwise', () {
      final observer = _Picky(null);
      expect(CobaltLogLevel.values.every(observer.accepts), isTrue);
    });
  });
}

/// Takes only [levels] — or, given null, whatever the base class takes — and
/// remembers every level it was asked about.
final class _Picky extends CobaltRecordingObserver {
  _Picky(this.levels);

  final Set<CobaltLogLevel>? levels;
  final asked = <CobaltLogLevel>[];
  final records = <CobaltLogRecord>[];

  @override
  bool accepts(CobaltLogLevel level) {
    asked.add(level);
    return levels?.contains(level) ?? super.accepts(level);
  }

  @override
  void onRecord(CobaltLogRecord record) => records.add(record);
}
