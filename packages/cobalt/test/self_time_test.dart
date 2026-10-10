import 'dart:io';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class Leaf {}

final class Branch {
  Branch(this.leaf);

  final Leaf leaf;
}

final class Left {}

final class Right {}

final class Both {}

final class Filled implements CobaltInjectable {
  late final Leaf leaf;

  @override
  void onInject(CobaltResolver resolver) => leaf = resolver.get<Leaf>();
}

final class _Timing extends CobaltObserver {
  final self = <String, Duration>{};
  final took = <String, Duration>{};
  final order = <String>[];

  @override
  void onInstanceSelfTime(CobaltScopeRef scope, CobaltKey key, Duration self) {
    order.add('self $key');
    this.self['$key'] = self;
  }

  @override
  void onInstanceBuilt(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
    required Duration took,
  }) {
    order.add('built $key');
    this.took['$key'] = took;
  }
}

final class _Recorded extends CobaltRecordingObserver {
  final records = <CobaltLogRecord>[];

  @override
  void onRecord(CobaltLogRecord record) => records.add(record);
}

const _leafWork = Duration(milliseconds: 60);
const _ownWork = Duration(milliseconds: 20);

void main() {
  group('onInstanceSelfTime', () {
    test('a build does not count the dependency it built', () {
      final timing = _Timing();
      cobaltTestRoot(observers: [timing])
        ..registerLazySingleton<Leaf>(
          FnFactory((_) {
            sleep(_leafWork);
            return Leaf();
          }),
        )
        ..registerLazySingleton<Branch>(
          FnFactory((resolver) {
            sleep(_ownWork);
            return Branch(resolver.get<Leaf>());
          }),
        )
        ..get<Branch>();

      expect(timing.took['Branch'], greaterThanOrEqualTo(_leafWork + _ownWork));
      expect(timing.self['Branch'], lessThan(_leafWork));
      expect(timing.self['Branch'], greaterThanOrEqualTo(_ownWork));
      expect(timing.self['Leaf'], greaterThanOrEqualTo(_leafWork));
    });

    test('comes between onInstanceCreated and onInstanceBuilt', () {
      final timing = _Timing();
      cobaltTestRoot(observers: [timing])
        ..registerLazySingleton<Leaf>(FnFactory((_) => Leaf()))
        ..get<Leaf>();

      expect(timing.order, ['self Leaf', 'built Leaf']);
    });

    test('an @injected dependency is not counted either', () {
      final timing = _Timing();
      cobaltTestRoot(observers: [timing])
        ..registerLazySingleton<Leaf>(
          FnFactory((_) {
            sleep(_leafWork);
            return Leaf();
          }),
        )
        ..registerLazySingleton<Filled>(FnFactory((_) => Filled()))
        ..get<Filled>();

      expect(timing.took['Filled'], greaterThanOrEqualTo(_leafWork));
      expect(timing.self['Filled'], lessThan(_leafWork));
    });

    test('an async build does not count what it awaited', () async {
      final timing = _Timing();
      final scope = cobaltTestRoot(observers: [timing])
        ..registerLazyAsyncSingleton<Leaf>(
          AsyncFnFactory((_) async {
            await Future<void>.delayed(_leafWork);
            return Leaf();
          }),
        )
        ..registerLazyAsyncSingleton<Branch>(
          AsyncFnFactory((resolver) async {
            await Future<void>.delayed(_ownWork);
            return Branch(await resolver.getAsync<Leaf>());
          }),
        );
      await scope.getAsync<Branch>();

      expect(timing.took['Branch'], greaterThanOrEqualTo(_leafWork + _ownWork));
      expect(timing.self['Branch'], lessThan(_leafWork));
    });

    test('dependencies awaited side by side never make it negative', () async {
      final timing = _Timing();
      final scope = cobaltTestRoot(observers: [timing])
        ..registerLazyAsyncSingleton<Left>(
          AsyncFnFactory((_) async {
            await Future<void>.delayed(_leafWork);
            return Left();
          }),
        )
        ..registerLazyAsyncSingleton<Right>(
          AsyncFnFactory((_) async {
            await Future<void>.delayed(_leafWork);
            return Right();
          }),
        )
        ..registerLazyAsyncSingleton<Both>(
          AsyncFnFactory((resolver) async {
            await Future.wait([
              resolver.getAsync<Left>(),
              resolver.getAsync<Right>(),
            ]);
            return Both();
          }),
        );
      await scope.getAsync<Both>();

      expect(timing.self['Both'], Duration.zero);
    });

    test('siblings built side by side by init() are not nested', () async {
      final timing = _Timing();
      final scope = cobaltTestRoot(observers: [timing])
        ..registerAsyncSingleton<Left>(
          AsyncFnFactory((_) async {
            await Future<void>.delayed(_leafWork);
            return Left();
          }),
        )
        ..registerAsyncSingleton<Right>(
          AsyncFnFactory((_) async {
            await Future<void>.delayed(_ownWork);
            return Right();
          }),
        );
      await scope.init();

      expect(timing.self['Left'], greaterThanOrEqualTo(_leafWork));
      expect(timing.self['Right'], greaterThanOrEqualTo(_ownWork));
    });
  });

  test('the creation record carries the build time without dependencies', () {
    final recorded = _Recorded();
    cobaltTestRoot(observers: [recorded])
      ..registerLazySingleton<Leaf>(
        FnFactory((_) {
          sleep(_leafWork);
          return Leaf();
        }),
      )
      ..registerLazySingleton<Branch>(
        FnFactory((resolver) => Branch(resolver.get<Leaf>())),
      )
      ..get<Branch>();

    final branch = recorded.records.singleWhere(
      (record) =>
          record.kind == CobaltEventKind.instanceCreated &&
          '${record.key}' == 'Branch',
    );
    expect(branch.took, greaterThanOrEqualTo(_leafWork));
    expect(branch.selfTook, lessThan(_leafWork));
    expect(branch.toStructured(), contains('self_us'));
  });
}
