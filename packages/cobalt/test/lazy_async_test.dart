import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class Engine implements Disposable {
  Engine(this.label, this.recorder);

  final String label;
  final DisposeRecorder recorder;

  @override
  void dispose() => recorder.record(label);
}

final class Index {
  Index(this.engine);

  final Engine engine;
}

final class First {}

final class Second {}

const _deadlock = Duration(seconds: 2);

void main() {
  late DisposeRecorder recorder;

  setUp(() => recorder = DisposeRecorder());

  group('building on demand', () {
    test(
      'nothing is built until the first getAsync, not even by init',
      () async {
        var built = 0;
        final scope = cobaltTestRoot()
          ..registerLazyAsyncSingleton<Engine>(
            AsyncFnFactory((_) async {
              built++;
              return Engine('engine', recorder);
            }),
          );

        await scope.init();
        expect(built, 0);

        await scope.getAsync<Engine>();
        expect(built, 1);
      },
    );

    test('concurrent callers share one build and one instance', () async {
      var built = 0;
      final gate = Completer<void>();
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async {
            built++;
            await gate.future;
            return Engine('engine', recorder);
          }),
        );

      final calls = [for (var i = 0; i < 10; i++) scope.getAsync<Engine>()];
      gate.complete();
      final engines = await Future.wait(calls);

      expect(built, 1);
      expect(engines.toSet(), hasLength(1));
      expect(await scope.getAsync<Engine>(), same(engines.first));
    });

    test('get reads a built instance and refuses an unbuilt one', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('engine', recorder)),
        );

      expect(
        () => scope.get<Engine>(),
        throwsA(
          isA<CobaltLazyAsyncError>().having(
            (error) => error.message,
            'message',
            contains('getAsync<Engine>()'),
          ),
        ),
      );

      final built = await scope.getAsync<Engine>();
      expect(scope.get<Engine>(), same(built));
    });

    test('getAll refuses an unbuilt one, and getAllAsync builds it', () async {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Engine>(
          FnFactory((_) => Engine('eager', recorder)),
          name: 'eager',
        )
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('lazy', recorder)),
          name: 'lazy',
        );

      expect(
        () => scope.getAll<Engine>(),
        throwsA(isA<CobaltLazyAsyncError>()),
      );

      final engines = await scope.getAllAsync<Engine>();
      expect([for (final engine in engines) engine.label], ['eager', 'lazy']);
      expect(scope.getAll<Engine>(), hasLength(2));
    });

    test('may be registered after init', () async {
      final scope = cobaltTestRoot();
      await scope.init();

      scope.registerLazyAsyncSingleton<Engine>(
        AsyncFnFactory((_) async => Engine('late', recorder)),
      );

      expect((await scope.getAsync<Engine>()).label, 'late');
    });
  });

  group('what a lazy build may wait for', () {
    test('another lazy registration, through the resolver', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('engine', recorder)),
        )
        ..registerLazyAsyncSingleton<Index>(
          AsyncFnFactory((resolver) async => Index(await resolver.getAsync())),
        );

      final index = await scope.getAsync<Index>();
      expect(index.engine, same(await scope.getAsync<Engine>()));
    });

    test(
      'a key another caller is building is waited for, not a cycle',
      () async {
        final gate = Completer<void>();
        final scope = cobaltTestRoot()
          ..registerLazyAsyncSingleton<Engine>(
            AsyncFnFactory((_) async {
              await gate.future;
              return Engine('engine', recorder);
            }),
          )
          ..registerLazyAsyncSingleton<Index>(
            AsyncFnFactory(
              (resolver) async => Index(await resolver.getAsync()),
            ),
          );

        final engine = scope.getAsync<Engine>();
        final index = scope.getAsync<Index>();
        gate.complete();

        expect((await index).engine, same(await engine));
      },
    );

    test(
      'its own key, through a chain, is a cycle and not a deadlock',
      () async {
        final scope = cobaltTestRoot()
          ..registerLazyAsyncSingleton<First>(
            AsyncFnFactory((resolver) async {
              await resolver.getAsync<Second>();
              return First();
            }),
          )
          ..registerLazyAsyncSingleton<Second>(
            AsyncFnFactory((resolver) async {
              await resolver.getAsync<First>();
              return Second();
            }),
          );

        await expectLater(
          scope.getAsync<First>().timeout(_deadlock),
          throwsA(
            isA<CobaltCycleError>().having((error) => error.cycle, 'cycle', [
              'First',
              'Second',
              'First',
            ]),
          ),
        );
      },
    );

    test('a cycle that closes after an await is still a cycle', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<First>(
          AsyncFnFactory((resolver) async {
            await Future<void>.delayed(Duration.zero);
            await resolver.getAsync<Second>();
            return First();
          }),
        )
        ..registerLazyAsyncSingleton<Second>(
          AsyncFnFactory((resolver) async {
            await Future<void>.delayed(Duration.zero);
            await resolver.getAsync<First>();
            return Second();
          }),
        );

      await expectLater(
        scope.getAsync<First>().timeout(_deadlock),
        throwsA(isA<CobaltCycleError>()),
      );
    });

    test('an async singleton init is still building is waited for', () async {
      final gate = Completer<void>();
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<Engine>(
          AsyncFnFactory((_) async {
            await gate.future;
            return Engine('eager', recorder);
          }),
        );

      final init = scope.init();
      final engine = scope.getAsync<Engine>();
      gate.complete();
      await init;

      expect((await engine).label, 'eager');
    });

    test(
      'inside init, an unbuilt async singleton throws instead of waiting',
      () async {
        final scope = cobaltTestRoot()
          ..registerAsyncSingleton<Index>(
            AsyncFnFactory(
              (resolver) async => Index(await resolver.getAsync()),
            ),
          )
          ..registerAsyncSingleton<Engine>(
            AsyncFnFactory((_) async => Engine('eager', recorder)),
          );

        await expectLater(
          scope.init().timeout(_deadlock),
          throwsA(isA<CobaltNotReadyError>()),
        );
      },
    );

    test('an async singleton cannot name a lazy one in dependsOn', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('lazy', recorder)),
        )
        ..registerAsyncSingleton<Index>(
          AsyncFnFactory((resolver) async => Index(await resolver.getAsync())),
          dependsOn: {const CobaltKey(Engine)},
        );

      await expectLater(
        scope.init(),
        throwsA(
          isA<CobaltDependsOnError>().having(
            (error) => error.reason,
            'reason',
            contains('lazy async'),
          ),
        ),
      );
    });

    test('a failure inside a lazy build names the lazy chain', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Index>(
          AsyncFnFactory((resolver) async => Index(resolver.get<Engine>())),
        );

      await expectLater(
        scope.getAsync<Index>(),
        throwsA(
          isA<CobaltNotRegisteredError>().having(
            (error) => error.resolving,
            'resolving',
            [const CobaltKey(Index)],
          ),
        ),
      );
    });
  });

  group('when a build fails', () {
    test(
      'everyone waiting gets the error, and the next call tries again',
      () async {
        var attempts = 0;
        final gate = Completer<void>();
        final scope = cobaltTestRoot()
          ..registerLazyAsyncSingleton<Engine>(
            AsyncFnFactory((_) async {
              attempts++;
              if (attempts == 1) {
                await gate.future;
                throw StateError('offline');
              }
              return Engine('engine', recorder);
            }),
          );

        final first = scope.getAsync<Engine>();
        final second = scope.getAsync<Engine>();
        gate.complete();

        await expectLater(first, throwsStateError);
        await expectLater(second, throwsStateError);

        expect((await scope.getAsync<Engine>()).label, 'engine');
        expect(attempts, 2);
      },
    );
  });

  group('teardown', () {
    test('what a lazy build made is released last-created-first', () async {
      final scope = CobaltScope.root()
        ..registerLazySingleton<Engine>(
          FnFactory((_) => Engine('sync', recorder)),
          name: 'sync',
        )
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('lazy', recorder)),
          name: 'lazy',
        );

      scope.get<Engine>(name: 'sync');
      await scope.getAsync<Engine>(name: 'lazy');
      await scope.dispose();

      expect(recorder.entries, ['lazy', 'sync']);
    });

    test('dispose waits for a build in flight, then releases it', () async {
      final gate = Completer<void>();
      final scope = CobaltScope.root()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async {
            await gate.future;
            return Engine('engine', recorder);
          }),
        );

      final engine = scope.getAsync<Engine>();
      final disposing = scope.dispose();
      gate.complete();

      expect((await engine).label, 'engine');
      await disposing;
      expect(recorder.entries, ['engine']);
      expect(scope.state, CobaltScopeState.disposed);
    });

    test('a build past the deadline is closed the moment it arrives', () async {
      final gate = Completer<void>();
      final scope = CobaltScope.root()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async {
            await gate.future;
            return Engine('late', recorder);
          }),
        );

      final engine = scope.getAsync<Engine>();
      final waiting = expectLater(
        engine,
        throwsA(isA<CobaltScopeStateError>()),
      );

      await expectLater(
        scope.dispose(timeout: const Duration(milliseconds: 20)),
        throwsA(
          isA<CobaltDisposeError>().having(
            (error) => error.hasTimeout,
            'hasTimeout',
            isTrue,
          ),
        ),
      );
      expect(recorder.entries, isEmpty);

      gate.complete();
      await waiting;
      expect(recorder.entries, ['late']);
    });

    test('a build that threw does not make dispose throw', () async {
      final gate = Completer<void>();
      final scope = CobaltScope.root()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async {
            await gate.future;
            throw StateError('offline');
          }),
        );

      final engine = expectLater(scope.getAsync<Engine>(), throwsStateError);
      final disposing = scope.dispose();
      gate.complete();

      await engine;
      await disposing;
      expect(scope.state, CobaltScopeState.disposed);
    });

    test('a scope being disposed starts no new build', () async {
      final gate = Completer<void>();
      final scope = CobaltScope.root()
        ..registerAsyncSingleton<First>(
          AsyncFnFactory((_) async {
            await gate.future;
            return First();
          }),
        )
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('engine', recorder)),
        );

      final init = scope.init();
      final disposing = scope.dispose();

      await expectLater(
        scope.getAsync<Engine>(),
        throwsA(isA<CobaltScopeStateError>()),
      );

      gate.complete();
      await init;
      await disposing;
    });

    test('the owner keeps what it built, not the scope that asked', () async {
      final root = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('engine', recorder)),
        );
      final child = root.push('child');

      final engine = await child.getAsync<Engine>();
      await child.dispose();

      expect(recorder.entries, isEmpty);
      expect(await root.getAsync<Engine>(), same(engine));
    });
  });

  group('for tools', () {
    test('debugKindOf names the lazy kind', () {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('engine', recorder)),
        );

      expect(
        scope.debugKindOf(const CobaltKey(Engine)),
        CobaltRegistrationKind.lazyAsyncSingleton,
      );
    });

    test('debugResolveAsync builds it', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('engine', recorder)),
        );

      final engine = await scope.debugResolveAsync(const CobaltKey(Engine));
      expect(engine, same(scope.get<Engine>()));
    });

    test('creation is reported with the lazy kind', () async {
      final observer = CapturingObserver();
      final scope = cobaltTestRoot(observers: [observer])
        ..registerLazyAsyncSingleton<Engine>(
          AsyncFnFactory((_) async => Engine('engine', recorder)),
        );

      await scope.getAsync<Engine>();

      expect(
        observer.records.where(
          (record) =>
              record.kind == CobaltEventKind.instanceCreated &&
              record.registrationKind ==
                  CobaltRegistrationKind.lazyAsyncSingleton,
        ),
        hasLength(1),
      );
    });
  });
}
