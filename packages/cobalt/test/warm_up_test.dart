import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class Engine {}

final class Index {}

final class Clock {}

void main() {
  group('warming up', () {
    test('builds every listed registration, once, at the same time', () async {
      final started = <String>[];
      final gate = Completer<void>();
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async {
            started.add('engine');
            await gate.future;
            return Engine();
          }),
        )
        ..registerLazyAsyncSingleton<Index>(
          AsyncFnFactory((_) async {
            started.add('index');
            await gate.future;
            return Index();
          }),
        );
      await scope.init();

      final warming = scope.warmUp(const [
        CobaltKey(Engine),
        CobaltKey(Index),
        CobaltKey(Engine),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(started, [
        'engine',
        'index',
      ], reason: 'both builds start before either finishes');

      gate.complete();
      await warming;

      expect(scope.get<Engine>(), same(await scope.getAsync<Engine>()));
      expect(scope.get<Index>(), isA<Index>());
      expect(started, hasLength(2));
    });

    test('shares the build a getAsync already started', () async {
      var built = 0;
      final gate = Completer<void>();
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async {
            built++;
            await gate.future;
            return Engine();
          }),
        );
      await scope.init();

      final asked = scope.getAsync<Engine>();
      final warming = scope.warmUp(const [CobaltKey(Engine)]);
      gate.complete();
      await warming;

      expect(await asked, same(scope.get<Engine>()));
      expect(built, 1);
    });

    test('builds on the scope that owns the registration', () async {
      final recorder = DisposeRecorder();
      final root = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine()),
          dispose: (_) => recorder.record('engine'),
        );
      await root.init();
      final child = root.push('screen');

      await child.warmUp(const [CobaltKey(Engine)]);
      await child.dispose();

      expect(
        recorder.entries,
        isEmpty,
        reason: 'the root owns it, so closing the screen leaves it alone',
      );
      expect(root.get<Engine>(), isA<Engine>());
      await root.dispose();
      expect(recorder.entries, ['engine']);
    });
  });

  group('when a build fails', () {
    test('the rest still build, and every failure is reported', () async {
      var engineAttempts = 0;
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async {
            if (++engineAttempts == 1) throw StateError('no engine');
            return Engine();
          }),
        )
        ..registerLazyAsyncSingleton<Index>(
          AsyncFnFactory((_) async => Index()),
        )
        ..registerLazyAsyncSingleton<Clock>(
          AsyncFnFactory((_) async => throw StateError('no clock')),
        );
      await scope.init();

      final error = await scope
          .warmUp(const [CobaltKey(Engine), CobaltKey(Index), CobaltKey(Clock)])
          .then<CobaltWarmUpError?>((_) => null)
          .catchError((Object e) => e as CobaltWarmUpError);

      expect(error, isNotNull);
      expect(error!.failures.keys, [
        const CobaltKey(Engine),
        const CobaltKey(Clock),
      ]);
      expect(error.stackTraces.keys, hasLength(2));
      expect(error.scopeName, scope.name);
      expect(error.message, contains('failed to build 2 registration(s)'));
      expect(scope.get<Index>(), isA<Index>());
      expect(
        await scope.getAsync<Engine>(),
        isA<Engine>(),
        reason: 'a failed build is not cached; the next getAsync tries again',
      );
    });
  });

  group('what it refuses before building anything', () {
    test('a key that is not a lazy async registration', () async {
      var built = 0;
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async {
            built++;
            return Engine();
          }),
        )
        ..registerLazySingleton<Clock>(FnFactory((_) => Clock()));
      await scope.init();

      expect(
        () => scope.warmUp(const [CobaltKey(Engine), CobaltKey(Clock)]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('lazySingleton registration, not a lazy async one'),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(built, 0);
    });

    test('a key nothing registers', () async {
      final scope = cobaltTestRoot();
      await scope.init();

      expect(
        () => scope.warmUp(const [CobaltKey(Engine)]),
        throwsA(isA<CobaltNotRegisteredError>()),
      );
    });
  });
}
