import 'dart:io';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class Thing {}

final class Slow {
  Slow(this.inner);

  final Thing inner;
}

typedef _Event = ({
  String event,
  CobaltKey key,
  CobaltRegistrationKind kind,
  bool retained,
  Duration? took,
});

final class _Watching extends CobaltObserver {
  final events = <_Event>[];

  @override
  void onInstanceCreated(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
  }) => events.add((
    event: 'created',
    key: key,
    kind: kind,
    retained: retained,
    took: null,
  ));

  @override
  void onInstanceBuilt(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
    required Duration took,
  }) => events.add((
    event: 'built',
    key: key,
    kind: kind,
    retained: retained,
    took: took,
  ));

  Duration tookFor(CobaltKey key) =>
      events.singleWhere((e) => e.event == 'built' && e.key == key).took!;
}

final class _Recorded extends CobaltRecordingObserver {
  final records = <CobaltLogRecord>[];

  @override
  void onRecord(CobaltLogRecord record) => records.add(record);
}

void main() {
  group('onInstanceBuilt', () {
    test('follows onInstanceCreated for every kind that is built', () async {
      final watching = _Watching();
      final scope = cobaltTestRoot(observers: [watching])
        ..registerSingleton<Thing>(Thing(), name: 'given')
        ..registerEagerSingleton<Thing>(
          FnFactory((_) => Thing()),
          name: 'eager',
        )
        ..registerLazySingleton<Thing>(FnFactory((_) => Thing()), name: 'lazy')
        ..registerFactory<Thing>(FnFactory((_) => Thing()), name: 'transient')
        ..registerParamFactory<Thing, int>(
          FnParamFactory((_, _) => Thing()),
          name: 'param',
        )
        ..registerAsyncSingleton<Thing>(
          AsyncFnFactory((_) async => Thing()),
          name: 'async',
        )
        ..registerLazyAsyncSingleton<Thing>(
          AsyncFnFactory((_) async => Thing()),
          name: 'lazyAsync',
        )
        ..registerAsyncFactory<Thing>(
          AsyncFnFactory((_) async => Thing()),
          name: 'asyncTransient',
        )
        ..registerAsyncParamFactory<Thing, int>(
          AsyncFnParamFactory((_, _) async => Thing()),
          name: 'asyncParam',
        );
      await scope.init();
      scope
        ..get<Thing>(name: 'lazy')
        ..get<Thing>(name: 'transient')
        ..getWithParam<Thing, int>(1, name: 'param');
      await scope.getAsync<Thing>(name: 'lazyAsync');
      await scope.getAsync<Thing>(name: 'asyncTransient');
      await scope.getAsyncWithParam<Thing, int>(1, name: 'asyncParam');

      final events = watching.events;
      expect(events, hasLength(16), reason: 'eight builds, two events each');
      for (var i = 0; i < events.length; i += 2) {
        final created = events[i];
        final built = events[i + 1];
        expect(created.event, 'created');
        expect(built.event, 'built');
        expect(built.key, created.key);
        expect(built.kind, created.kind);
        expect(built.retained, created.retained);
      }
      expect(
        events.map((e) => e.key.name).toSet(),
        isNot(contains('given')),
        reason: 'a value handed over already made was not built here',
      );
    });

    test('an async build includes what it awaited', () async {
      final watching = _Watching();
      final scope = cobaltTestRoot(observers: [watching])
        ..registerAsyncFactory<Thing>(
          AsyncFnFactory((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return Thing();
          }),
        );

      await scope.getAsync<Thing>();

      expect(
        watching.tookFor(const CobaltKey(Thing)),
        greaterThanOrEqualTo(const Duration(milliseconds: 30)),
      );
    });

    test('a build includes the builds it resolved on the way', () {
      final watching = _Watching();
      final scope = cobaltTestRoot(observers: [watching])
        ..registerLazySingleton<Thing>(
          FnFactory((_) {
            sleep(const Duration(milliseconds: 20));
            return Thing();
          }),
        )
        ..registerLazySingleton<Slow>(FnFactory((r) => Slow(r.get<Thing>())));

      scope.get<Slow>();

      expect(
        watching.tookFor(const CobaltKey(Slow)),
        greaterThanOrEqualTo(watching.tookFor(const CobaltKey(Thing))),
      );
      expect(
        watching.tookFor(const CobaltKey(Thing)),
        greaterThanOrEqualTo(const Duration(milliseconds: 20)),
      );
    });
  });

  group('the recording observer', () {
    test('writes one creation record per build, with its time', () async {
      final recorded = _Recorded();
      final scope = cobaltTestRoot(observers: [recorded])
        ..registerFactory<Thing>(FnFactory((_) => Thing()));

      scope
        ..get<Thing>()
        ..get<Thing>();

      final created = recorded.records
          .where((r) => r.kind == CobaltEventKind.instanceCreated)
          .toList();
      expect(created, hasLength(2));
      expect(created.first.took, isNotNull);
      expect(
        created.first.message,
        matches(
          RegExp(
            r'^built Thing in "root" as transient, not retained, '
            r'in \d+(µs|ms)$',
          ),
        ),
      );
      expect(
        created.first.toStructured(),
        containsPair('took_us', created.first.took!.inMicroseconds),
      );
    });
  });
}
