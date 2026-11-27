import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

class Leaf extends Recorder {
  Leaf() : super('Leaf');
}

class Trunk extends Recorder {
  Trunk(this.leaf) : super('Trunk');

  final Leaf leaf;
}

class LeafFactory implements CobaltFactory<Leaf> {
  const LeafFactory();

  @override
  Leaf create(CobaltResolver resolver) => Leaf();
}

class TrunkFactory implements CobaltFactory<Trunk> {
  const TrunkFactory();

  @override
  Trunk create(CobaltResolver resolver) => Trunk(resolver.get<Leaf>());
}

class AsyncLeaf implements AsyncDisposable {
  AsyncLeaf() : _recorder = recorder;

  final DisposeRecorder _recorder;

  @override
  Future<void> dispose() async => _recorder.record('AsyncLeaf');
}

class AsyncLeafFactory implements CobaltAsyncFactory<AsyncLeaf> {
  const AsyncLeafFactory();

  @override
  Future<AsyncLeaf> create(CobaltResolver resolver) async => AsyncLeaf();
}

class SlowClosing implements AsyncDisposable {
  SlowClosing(this.label, [this.delay = Duration.zero]) : _recorder = recorder;

  final String label;
  final Duration delay;
  final DisposeRecorder _recorder;

  @override
  Future<void> dispose() async {
    _recorder.record('$label start');
    await Future<void>.delayed(delay);
    _recorder.record('$label end');
  }
}

void main() {
  setUp(resetLogs);

  group('dispose ordering', () {
    test('disposes by creation order, not registration order', () async {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Trunk>(const TrunkFactory())
        ..registerLazySingleton<Leaf>(const LeafFactory());

      scope.get<Trunk>();
      await scope.dispose();

      expect(recorder.entries, ['Trunk', 'Leaf']);
    });

    test('children are disposed before the parent', () async {
      final root = cobaltTestRoot()..registerSingleton(Recorder('root'));
      final child = root.push('child')..registerSingleton(Recorder('child'));
      child.push('grandchild').registerSingleton(Recorder('grandchild'));

      await root.dispose();

      expect(recorder.entries, ['grandchild', 'child', 'root']);
    });

    test('sibling scopes dispose last in first out', () async {
      final root = cobaltTestRoot();
      root.push('first').registerSingleton(Recorder('first'));
      root.push('second').registerSingleton(Recorder('second'));

      await root.dispose();

      expect(recorder.entries, ['second', 'first']);
    });

    test('async disposables are awaited', () async {
      final scope = cobaltTestRoot()
        ..registerSingleton(AsyncRecorder('slow'))
        ..registerSingleton(Recorder('fast'));

      await scope.dispose();

      expect(recorder.entries, ['fast', 'slow']);
    });

    test('transient instances are not owned by the scope', () async {
      final scope = cobaltTestRoot()
        ..registerFactory<Leaf>(const LeafFactory());

      scope.get<Leaf>();
      await scope.dispose();

      expect(recorder.entries, isEmpty);
    });

    test('a disposed child detaches from its parent', () async {
      final root = cobaltTestRoot();
      final child = root.push('child');

      await child.dispose();

      expect(root.children, isEmpty);
      expect(child.state, CobaltScopeState.disposed);
      expect(root.state, CobaltScopeState.open);
    });

    test('dispose is idempotent', () async {
      final scope = cobaltTestRoot()..registerSingleton(Recorder('only'));

      await scope.dispose();
      await scope.dispose();

      expect(recorder.entries, ['only']);
    });

    test('a second dispose waits for the first to finish', () async {
      final scope = cobaltTestRoot()
        ..registerSingleton(
          SlowClosing('only', const Duration(milliseconds: 30)),
        );

      final first = scope.dispose();
      await scope.dispose();
      recorder.record('second returned');
      await first;

      expect(recorder.entries, ['only start', 'only end', 'second returned']);
    });

    test('a parent waits for a child that is already closing', () async {
      final root = cobaltTestRoot()..registerSingleton(SlowClosing('parent'));
      final child = root.push('child')
        ..registerSingleton(
          SlowClosing('child', const Duration(milliseconds: 30)),
        );

      final closing = child.dispose();
      await root.dispose();
      await closing;

      expect(recorder.entries, [
        'child start',
        'child end',
        'parent start',
        'parent end',
      ]);
    });

    test('a disposed scope refuses further use', () async {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Leaf>(const LeafFactory());
      await scope.dispose();

      expect(() => scope.get<Leaf>(), throwsA(isA<CobaltScopeStateError>()));
      expect(() => scope.push('late'), throwsA(isA<CobaltScopeStateError>()));
    });
  });

  group('async initialization', () {
    test('runs dependents strictly after their dependencies', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<SlowService>(const SlowFactory('database', 10))
        ..registerAsyncSingleton<AsyncLeaf>(
          const AsyncLeafFactory(),
          dependsOn: {const CobaltKey(SlowService)},
        );

      await scope.init();

      expect(scope.state, CobaltScopeState.active);
      expect(initLog, ['database']);
    });

    test('independent branches run in parallel', () async {
      final started = <String>[];
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<SlowService>(
          SlowFactory('a', 30, started: started),
        )
        ..registerAsyncSingleton<SlowService>(
          SlowFactory('b', 30, started: started),
          name: 'b',
        );

      final init = scope.init();

      expect(started, ['a', 'b']);
      expect(initLog, isEmpty);
      await init;
      expect(initLog, hasLength(2));
    });

    test('a dependent chain runs sequentially', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<SlowService>(const SlowFactory('first', 120))
        ..registerAsyncSingleton<SlowService>(
          const SlowFactory('second', 120),
          name: 'second',
          dependsOn: {const CobaltKey(SlowService)},
        );

      final watch = Stopwatch()..start();
      await scope.init();
      watch.stop();

      expect(initLog, ['first', 'second']);
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(220));
    });

    test('an async singleton is unavailable before init', () {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<SlowService>(const SlowFactory('x', 0));

      expect(
        () => scope.get<SlowService>(),
        throwsA(isA<CobaltNotReadyError>()),
      );
    });

    test('a cycle fails loudly instead of deadlocking', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<SlowService>(
          const SlowFactory('a', 0),
          dependsOn: {const CobaltKey(AsyncLeaf)},
        )
        ..registerAsyncSingleton<AsyncLeaf>(
          const AsyncLeafFactory(),
          dependsOn: {const CobaltKey(SlowService)},
        );

      await expectLater(scope.init(), throwsA(isA<CobaltCycleError>()));
    });

    test('init is idempotent', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<SlowService>(const SlowFactory('once', 0));

      await scope.init();
      await scope.init();

      expect(initLog, ['once']);
    });

    test(
      'async singletons are disposed like any other owned instance',
      () async {
        final scope = cobaltTestRoot()
          ..registerAsyncSingleton<AsyncLeaf>(const AsyncLeafFactory());

        await scope.init();
        await scope.dispose();

        expect(recorder.entries, ['AsyncLeaf']);
      },
    );
  });
}
