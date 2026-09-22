import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('checkGraph', () {
    test('a complete graph resolves', () async {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Clock>(const ValueFactory(Clock()))
        ..registerLazySingleton<Api>(FnFactory((r) => Api(r.get<Clock>())));

      final report = await checkGraph(scope);

      expect(report.isComplete, isTrue);
      expect(report.entries, hasLength(2));
    });

    test(
      'builds a lazy async registration, and reports what it misses',
      () async {
        final scope = cobaltTestRoot()
          ..registerLazySingleton<Clock>(const ValueFactory(Clock()))
          ..registerLazyAsyncSingleton<Api>(
            AsyncFnFactory((r) async => Api(r.get<Clock>())),
          )
          ..registerLazyAsyncSingleton<Broken>(
            AsyncFnFactory((r) async => Broken(r.get<Logger>())),
          );

        final report = await checkGraph(scope);

        expect(report.failures.single.key, const CobaltKey(Broken));
        expect(report.failures.single.error, isA<CobaltNotRegisteredError>());
        expect(scope.get<Api>(), isA<Api>());
      },
    );

    test('names a dependency nothing registers', () async {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Broken>(
          FnFactory((r) => Broken(r.get<Logger>())),
        );

      final report = await checkGraph(scope);

      expect(report.isComplete, isFalse);
      expect(report.failures.single.key, const CobaltKey(Broken));
      expect(report.failures.single.error, isA<CobaltNotRegisteredError>());
    });

    test('reports every hole at once, not the first', () async {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Broken>(
          FnFactory((r) => Broken(r.get<Logger>())),
        )
        ..registerLazySingleton<Api>(FnFactory((r) => Api(r.get<Clock>())));

      final report = await checkGraph(scope);

      expect(report.failures, hasLength(2));
    });

    test('expectGraphResolves fails with every hole listed', () async {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Broken>(
          FnFactory((r) => Broken(r.get<Logger>())),
        );

      await expectLater(
        expectGraphResolves(scope),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Broken'),
          ),
        ),
      );
    });

    test('sees what an ancestor registered', () async {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Clock>(const ValueFactory(Clock()));
      final child = root.pushForTest()
        ..registerLazySingleton<Api>(FnFactory((r) => Api(r.get<Clock>())));

      final report = await checkGraph(child);

      expect(report.isComplete, isTrue);
      expect(report.entries, hasLength(2));
    });
  });

  group('what it cannot check', () {
    test(
      'a parameterized registration is listed by name, not skipped',
      () async {
        final scope = cobaltTestRoot()
          ..registerParamFactory<Ticket, String>(const TicketFactory());

        final report = await checkGraph(scope);

        expect(report.unchecked.single.key, const CobaltKey(Ticket));
        expect(report.unchecked.single.reason, contains('parameterized'));
        expect(report.isComplete, isTrue, reason: 'unchecked is not failed');
      },
    );

    test('a sample value makes it checkable', () async {
      final scope = cobaltTestRoot()
        ..registerParamFactory<Ticket, String>(const TicketFactory());

      final report = await checkGraph(
        scope,
        params: {const CobaltKey(Ticket): 'abc'},
      );

      expect(report.unchecked, isEmpty);
      expect(report.entries.single.outcome, CobaltGraphOutcome.resolved);
    });
  });

  group('side effects it is honest about', () {
    test('an async singleton is initialised before being resolved', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<Clock>(const AsyncFnFactory(_slowClock));

      final report = await checkGraph(scope);

      expect(report.isComplete, isTrue);
      expect(scope.state, CobaltScopeState.active);
    });

    test(
      'it builds every lazy singleton, which is why it is terminal',
      () async {
        var built = 0;
        final scope = cobaltTestRoot()
          ..registerLazySingleton<Clock>(
            FnFactory((_) {
              built++;
              return const Clock();
            }),
          );

        expect(built, 0);
        await checkGraph(scope);
        expect(built, 1, reason: 'resolving is the check; there is no dry run');
      },
    );

    test(
      'a transient it built is disposed, since the scope will not',
      () async {
        final recorder = DisposeRecorder();
        final scope = cobaltTestRoot()
          ..registerFactory<Disposable>(recorder.factory('loose'));

        await checkGraph(scope);

        expect(recorder.entries, ['loose']);
      },
    );

    test('a cycle arrives with its path', () async {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Api>(FnFactory((r) => r.get<Api>()));

      final report = await checkGraph(scope);

      expect(report.failures.single.error, isA<CobaltCycleError>());
    });
  });
}

Future<Clock> _slowClock(CobaltResolver resolver) async {
  await Future<void>.delayed(Duration.zero);
  return const Clock();
}
