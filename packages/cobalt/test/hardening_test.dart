import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

class Alpha {
  Alpha(this.beta);

  final Beta beta;
}

class Beta {
  Beta(this.alpha);

  final Alpha alpha;
}

class AlphaFactory implements CobaltFactory<Alpha> {
  const AlphaFactory();

  @override
  Alpha create(CobaltResolver resolver) => Alpha(resolver.get<Beta>());
}

class BetaFactory implements CobaltFactory<Beta> {
  const BetaFactory();

  @override
  Beta create(CobaltResolver resolver) => Beta(resolver.get<Alpha>());
}

class SelfHungry {
  SelfHungry(this.other);

  final SelfHungry other;
}

class SelfHungryFactory implements CobaltFactory<SelfHungry> {
  const SelfHungryFactory();

  @override
  SelfHungry create(CobaltResolver resolver) =>
      SelfHungry(resolver.get<SelfHungry>());
}

class Counter {
  Counter() {
    instances++;
  }

  static var instances = 0;
}

class CountingFactory implements CobaltAsyncFactory<Counter> {
  const CountingFactory();

  @override
  Future<Counter> create(CobaltResolver resolver) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return Counter();
  }
}

class Exploding implements CobaltAsyncFactory<Counter> {
  const Exploding();

  @override
  Future<Counter> create(CobaltResolver resolver) async =>
      throw StateError('init failed');
}

class NeverReady implements CobaltScopeBuilder {
  const NeverReady();

  @override
  void build(CobaltScope scope) => scope.registerAsyncSingleton<Counter>(
    AsyncFnFactory((_) => Completer<Counter>().future),
  );
}

void main() {
  setUp(() {
    resetLogs();
    Counter.instances = 0;
  });

  group('runtime cycle detection', () {
    test('a two-node cycle throws instead of overflowing the stack', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Alpha>(const AlphaFactory())
        ..registerLazySingleton<Beta>(const BetaFactory());

      expect(() => scope.get<Alpha>(), throwsA(isA<CobaltCycleError>()));
    });

    test('the error names the resolution path', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Alpha>(const AlphaFactory())
        ..registerLazySingleton<Beta>(const BetaFactory());

      try {
        scope.get<Alpha>();
        fail('expected CobaltCycleError');
      } on CobaltCycleError catch (error) {
        expect(error.cycle.first, error.cycle.last);
        expect(error.cycle, containsAllInOrder(['Alpha', 'Beta', 'Alpha']));
      }
    });

    test('self dependency is caught', () {
      final scope = cobaltTestRoot()
        ..registerFactory<SelfHungry>(const SelfHungryFactory());

      expect(() => scope.get<SelfHungry>(), throwsA(isA<CobaltCycleError>()));
    });

    test('the tracker is shared across the scope tree', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Alpha>(const AlphaFactory())
        ..registerLazySingleton<Beta>(const BetaFactory());
      final child = root.push('child');

      expect(() => child.get<Alpha>(), throwsA(isA<CobaltCycleError>()));
    });

    test('a parent still cannot see what only the child registered', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Alpha>(const AlphaFactory());
      final child = root.push('child')
        ..registerLazySingleton<Beta>(const BetaFactory());

      expect(
        () => child.get<Beta>(),
        throwsA(isA<CobaltNotRegisteredError>()),
        reason: 'resolution never walks downwards',
      );
    });

    test('the tracker unwinds so later resolves still work', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Alpha>(const AlphaFactory())
        ..registerLazySingleton<Beta>(const BetaFactory())
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(() => scope.get<Alpha>(), throwsA(isA<CobaltCycleError>()));
      expect(scope.get<Logger>(), isNotNull);
    });

    /// Phase 1 stays off the tracker, which is shared by the whole tree: a key
    /// one scope built in a parallel level must not be read as a cycle by the
    /// next scope registering that key.
    test('a parallel level leaves no key behind for a later scope', () async {
      final root = cobaltTestRoot(name: 'app')
        ..registerAsyncSingleton<SlowService>(
          const SlowFactory('fast', 0),
          name: 'fast',
        )
        ..registerAsyncSingleton<SlowService>(
          const SlowFactory('slow', 30),
          name: 'slow',
        );
      await root.init();

      final child = root.push('child')
        ..registerAsyncSingleton<SlowService>(
          const SlowFactory('again', 0),
          name: 'fast',
        );

      await child.init();

      expect(child.state, CobaltScopeState.active);
      expect(child.get<SlowService>(name: 'fast'), isNotNull);
    });

    test('siblings building the same async singleton are no cycle', () async {
      final root = cobaltTestRoot();
      final first = root.push('first')
        ..registerAsyncSingleton<SlowService>(const SlowFactory('first', 20));
      final second = root.push('second')
        ..registerAsyncSingleton<SlowService>(const SlowFactory('second', 20));

      await Future.wait([first.init(), second.init()]);

      expect(first.get<SlowService>().label, 'first');
      expect(second.get<SlowService>().label, 'second');
    });

    test(
      'a lazy build of a key a sibling is initializing is no cycle',
      () async {
        final root = cobaltTestRoot();
        final first = root.push('first')
          ..registerAsyncSingleton<SlowService>(const SlowFactory('first', 20));
        final second = root.push('second')
          ..registerLazySingleton<SlowService>(
            FnFactory((_) => SlowService('second')),
          );
        final init = first.init();

        expect(second.get<SlowService>().label, 'second');
        await init;
      },
    );

    test('a scope reopened after an init timeout times out again', () async {
      final root = cobaltTestRoot();

      for (final name in ['first', 'second']) {
        await expectLater(
          root.open(
            name,
            const NeverReady(),
            initTimeout: const Duration(milliseconds: 10),
          ),
          throwsA(isA<CobaltInitTimeoutError>()),
        );
      }
    });

    test('a diamond is not mistaken for a cycle', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory())
        ..registerLazySingleton<ApiClient>(const ApiClientFactory());

      expect(scope.get<ApiClient>().logger, same(scope.get<Logger>()));
    });
  });

  group('init is safe to call more than once', () {
    test('concurrent init calls build the graph exactly once', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<Counter>(const CountingFactory());

      await Future.wait([scope.init(), scope.init(), scope.init()]);

      expect(Counter.instances, 1);
      expect(scope.state, CobaltScopeState.active);
    });

    test('sequential init calls are a no-op after the first', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<Counter>(const CountingFactory());

      await scope.init();
      await scope.init();

      expect(Counter.instances, 1);
    });

    test('init after dispose is rejected', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<Counter>(const CountingFactory());
      await scope.init();
      await scope.dispose();

      expect(scope.init, throwsA(isA<CobaltScopeStateError>()));
    });
  });

  group('dispose racing init', () {
    test('dispose waits for a running init and still ends disposed', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<Counter>(const CountingFactory());

      final init = scope.init();
      final dispose = scope.dispose();
      await Future.wait([init, dispose]);

      expect(scope.state, CobaltScopeState.disposed);
    });

    test('what a racing init built is still torn down', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<AsyncRecorder>(const RecorderFactory());

      final init = scope.init();
      final dispose = scope.dispose();
      await Future.wait([init, dispose]);

      expect(recorder.entries, ['async-singleton']);
      expect(scope.state, CobaltScopeState.disposed);
    });

    test('a failed init still lets the scope be disposed', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<Counter>(const Exploding());

      await expectLater(scope.init(), throwsA(isA<StateError>()));
      await scope.dispose();

      expect(scope.state, CobaltScopeState.disposed);
    });
  });
}
