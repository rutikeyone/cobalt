import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

class ThrowingDisposable implements Disposable {
  ThrowingDisposable(this.label);

  final String label;

  @override
  void dispose() => throw StateError('$label refused to close');
}

class ThrowingAsyncDisposable implements AsyncDisposable {
  ThrowingAsyncDisposable(this.label);

  final String label;

  @override
  Future<void> dispose() async => throw StateError('$label refused to close');
}

class NeverFinishes implements AsyncDisposable {
  NeverFinishes(this.label);

  final String label;

  @override
  Future<void> dispose() => Completer<void>().future;
}

class SlowDisposable implements AsyncDisposable {
  SlowDisposable(this.label, this.delay) : _recorder = recorder;

  final String label;

  final DisposeRecorder _recorder;
  final Duration delay;

  @override
  Future<void> dispose() async {
    await Future<void>.delayed(delay);
    _recorder.record(label);
  }
}

class FailingInit implements CobaltAsyncFactory<Recorder> {
  const FailingInit();

  @override
  Future<Recorder> create(CobaltResolver resolver) async =>
      throw StateError('the database refused to open');
}

class FailingAsyncInit implements CobaltAsyncFactory<AsyncRecorder> {
  const FailingAsyncInit();

  @override
  Future<AsyncRecorder> create(CobaltResolver resolver) async =>
      throw StateError('boom');
}

class StuckInit implements CobaltAsyncFactory<Recorder> {
  const StuckInit();

  @override
  Future<Recorder> create(CobaltResolver resolver) =>
      Completer<Recorder>().future;
}

class ClosesScope implements AsyncDisposable {
  ClosesScope(this.label) : _recorder = recorder;

  final String label;
  final DisposeRecorder _recorder;
  late final CobaltScope scope;

  @override
  Future<void> dispose() async {
    await scope.dispose();
    _recorder.record(label);
  }
}

final class DisposesOnStart extends CobaltObserver {
  late final CobaltScope scope;
  final calls = <Future<void>>[];
  var started = 0;

  @override
  void onScopeDisposeStarted(CobaltScopeRef ref) {
    started++;
    calls.add(scope.dispose());
  }
}

void main() {
  setUp(resetLogs);

  test('a hanging init no longer blocks teardown forever', () async {
    final scope = cobaltTestRoot(name: 'app')
      ..registerAsyncSingleton<Recorder>(const StuckInit());
    unawaited(scope.init());

    await expectLater(
      scope.dispose(timeout: const Duration(milliseconds: 50)),
      throwsA(
        isA<CobaltDisposeError>()
            .having((e) => e.scopeName, 'scopeName', 'app')
            .having((e) => e.hasTimeout, 'hasTimeout', isTrue)
            .having(
              (e) => e.failures.map((f) => f.label),
              'labels',
              contains('init'),
            ),
      ),
    );

    expect(scope.state, CobaltScopeState.disposed);
  });

  test('a hanging disposable is reported by type', () async {
    final scope = cobaltTestRoot()..registerSingleton(NeverFinishes('stuck'));

    await expectLater(
      scope.dispose(timeout: const Duration(milliseconds: 50)),
      throwsA(
        isA<CobaltDisposeError>().having(
          (e) => e.failures.map((f) => f.label),
          'labels',
          contains('NeverFinishes.dispose'),
        ),
      ),
    );

    expect(scope.state, CobaltScopeState.disposed);
  });

  test('teardown continues past a step that timed out', () async {
    final scope = cobaltTestRoot()
      ..registerSingleton(Recorder('first'), name: 'first')
      ..registerSingleton(NeverFinishes('stuck'))
      ..registerSingleton(Recorder('last'), name: 'last');

    await expectLater(
      scope.dispose(timeout: const Duration(milliseconds: 50)),
      throwsA(isA<CobaltDisposeError>()),
    );

    expect(
      recorder.entries,
      ['last', 'first'],
      reason: 'the sync disposables on both sides of the stuck one still ran',
    );
  });

  test('the deadline covers the whole tree, not each step', () async {
    final scope = cobaltTestRoot();
    for (var index = 0; index < 10; index++) {
      scope.registerSingleton(NeverFinishes('$index'), name: '$index');
    }

    final watch = Stopwatch()..start();
    await expectLater(
      scope.dispose(timeout: const Duration(milliseconds: 100)),
      throwsA(isA<CobaltDisposeError>()),
    );
    watch.stop();

    expect(watch.elapsedMilliseconds, lessThan(500));
  });

  test('a child that overruns is reported under its own name', () async {
    final root = cobaltTestRoot(name: 'app');
    root.push('session').registerSingleton(NeverFinishes('stuck'));

    await expectLater(
      root.dispose(timeout: const Duration(milliseconds: 50)),
      throwsA(
        isA<CobaltDisposeError>().having(
          (e) => e.failures.map((f) => f.label),
          'labels',
          contains('session/NeverFinishes.dispose'),
        ),
      ),
    );

    expect(root.state, CobaltScopeState.disposed);
  });

  test('teardown well inside the budget stays quiet', () async {
    final scope = cobaltTestRoot()
      ..registerSingleton(
        SlowDisposable('slow', const Duration(milliseconds: 10)),
      );

    await scope.dispose(timeout: const Duration(seconds: 5));

    expect(recorder.entries, ['slow']);
    expect(scope.state, CobaltScopeState.disposed);
  });

  test('a throwing disposable does not strand the rest', () async {
    final scope = cobaltTestRoot()
      ..registerSingleton(Recorder('first'), name: 'first')
      ..registerSingleton(ThrowingDisposable('broken'))
      ..registerSingleton(Recorder('last'), name: 'last');

    await expectLater(
      scope.dispose(),
      throwsA(
        isA<CobaltDisposeError>()
            .having((e) => e.hasTimeout, 'hasTimeout', isFalse)
            .having((e) => e.failures, 'failures', hasLength(1))
            .having((e) => e.failures.single.error, 'cause', isA<StateError>()),
      ),
    );

    expect(recorder.entries, ['last', 'first']);
    expect(scope.state, CobaltScopeState.disposed);
  });

  test('an async disposable that throws is recorded too', () async {
    final scope = cobaltTestRoot()
      ..registerSingleton(ThrowingAsyncDisposable('broken'));

    await expectLater(
      scope.dispose(),
      throwsA(
        isA<CobaltDisposeError>().having(
          (e) => e.failures.single.label,
          'label',
          'ThrowingAsyncDisposable.dispose',
        ),
      ),
    );
  });

  test('timeouts and exceptions are reported together', () async {
    final scope = cobaltTestRoot()
      ..registerSingleton(ThrowingDisposable('broken'))
      ..registerSingleton(NeverFinishes('stuck'));

    await expectLater(
      scope.dispose(timeout: const Duration(milliseconds: 50)),
      throwsA(
        isA<CobaltDisposeError>()
            .having((e) => e.failures, 'failures', hasLength(2))
            .having((e) => e.timeouts, 'timeouts', hasLength(1)),
      ),
    );
  });

  test('a failure inside a child is reported under the child name', () async {
    final root = cobaltTestRoot(name: 'app');
    root.push('session').registerSingleton(ThrowingDisposable('broken'));

    await expectLater(
      root.dispose(),
      throwsA(
        isA<CobaltDisposeError>().having(
          (e) => e.failures.single.label,
          'label',
          'session/ThrowingDisposable.dispose',
        ),
      ),
    );

    expect(root.state, CobaltScopeState.disposed);
  });

  group('a teardown already running', () {
    test('only the call that started it gets the error', () async {
      final scope = cobaltTestRoot()
        ..registerSingleton(ThrowingDisposable('broken'));

      final first = scope.dispose();
      final second = scope.dispose();

      await expectLater(first, throwsA(isA<CobaltDisposeError>()));
      await second;
      await scope.dispose();
      expect(scope.state, CobaltScopeState.disposed);
    });

    test('a parent joining a closing child keeps its own deadline', () async {
      final root = cobaltTestRoot(name: 'app');
      final child = root.push('session')
        ..registerSingleton(NeverFinishes('stuck'));
      child.dispose().ignore();

      final watch = Stopwatch()..start();
      await expectLater(
        root.dispose(timeout: const Duration(milliseconds: 100)),
        throwsA(
          isA<CobaltDisposeError>().having(
            (e) => e.timeouts.map((f) => f.label),
            'timeouts',
            ['session/dispose'],
          ),
        ),
      );
      watch.stop();

      expect(watch.elapsedMilliseconds, lessThan(1000));
    });

    test('dispose from onScopeDisposeStarted starts no second one', () async {
      final observer = DisposesOnStart();
      final scope = observer.scope = cobaltTestRoot(observers: [observer])
        ..registerSingleton(Recorder('only'));

      await scope.dispose();
      await Future.wait(observer.calls);

      expect(observer.started, 1);
      expect(recorder.entries, ['only']);
    });

    test('a disposable closing its own scope does not wait for it', () async {
      final closer = ClosesScope('closer');
      final scope = closer.scope = cobaltTestRoot()..registerSingleton(closer);

      await scope.dispose(timeout: const Duration(seconds: 2));

      expect(recorder.entries, ['closer']);
      expect(scope.state, CobaltScopeState.disposed);
    });

    test('a child disposable closing the root does not wait for it', () async {
      final closer = ClosesScope('closer');
      final root = closer.scope = cobaltTestRoot();
      root.push('session').registerSingleton(closer);

      await root.dispose(timeout: const Duration(seconds: 2));

      expect(recorder.entries, ['closer']);
      expect(root.state, CobaltScopeState.disposed);
    });

    test('a failed child init keeps its stage under the parent', () async {
      final root = cobaltTestRoot(name: 'app');
      final child = root.push('session')
        ..registerSingleton(ThrowingDisposable('broken'))
        ..registerAsyncSingleton<Recorder>(const FailingInit());
      await expectLater(child.init(), throwsA(isA<StateError>()));

      try {
        await root.dispose();
        fail('expected CobaltDisposeError');
      } on CobaltDisposeError catch (error) {
        final context = error.initFailures.single;
        expect(context.label, 'session/init');
        expect(context.isInitFailure, isTrue);
        expect(
          error.releaseFailures.single.label,
          'session/ThrowingDisposable.dispose',
        );
      }
    });
  });

  group('a failed init', () {
    test('does not make teardown itself fail', () async {
      final scope = cobaltTestRoot(name: 'app')
        ..registerSingleton(Recorder('early'))
        ..registerAsyncSingleton<Recorder>(const FailingInit(), name: 'async');
      await expectLater(scope.init(), throwsA(isA<StateError>()));

      await scope.dispose();

      expect(recorder.entries, ['early']);
      expect(scope.state, CobaltScopeState.disposed);
    });

    test('is listed as context when teardown also fails', () async {
      final scope = cobaltTestRoot()
        ..registerSingleton(ThrowingDisposable('broken'))
        ..registerAsyncSingleton<Recorder>(const FailingInit());
      await expectLater(scope.init(), throwsA(isA<StateError>()));

      try {
        await scope.dispose();
        fail('expected CobaltDisposeError');
      } on CobaltDisposeError catch (error) {
        expect(error.failures, hasLength(2));
        expect(error.releaseFailures, hasLength(1));

        final context = error.initFailures.single;
        expect(context.isInitFailure, isTrue);
        expect(context.stage, CobaltDisposeStage.awaitingInit);
        expect(context.toString(), contains('initialization failed'));
        expect(error.toString(), contains('never fully built'));
      }
    });

    test('a still-running init that hangs is a teardown failure', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<Recorder>(const StuckInit());
      unawaited(scope.init());

      await expectLater(
        scope.dispose(timeout: const Duration(milliseconds: 50)),
        throwsA(isA<CobaltDisposeError>()),
      );

      expect(scope.state, CobaltScopeState.disposed);
    });
  });

  test('the default budget is generous enough for ordinary teardown', () async {
    final scope = cobaltTestRoot()
      ..registerSingleton(AsyncRecorder('async'))
      ..registerSingleton(Recorder('sync'));

    await scope.dispose();

    expect(recorder.entries, ['sync', 'async']);
  });
}
