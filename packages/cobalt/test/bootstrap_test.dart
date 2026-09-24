import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

final bootLog = <String>[];

class RecordingStep implements CobaltBootstrapStep {
  RecordingStep(this.name, {this.millis = 0});

  @override
  final String name;

  final int millis;

  @override
  FutureOr<void> run() async {
    if (millis > 0) await Future<void>.delayed(Duration(milliseconds: millis));
    bootLog.add(name);
  }
}

class SyncStep implements CobaltBootstrapStep {
  SyncStep(this.name);

  @override
  final String name;

  @override
  void run() => bootLog.add(name);
}

class ClosingStep implements CobaltBootstrapStep, Disposable {
  ClosingStep(this.name) : _recorder = recorder;

  @override
  final String name;

  final DisposeRecorder _recorder;

  var isClosed = false;

  @override
  void run() => bootLog.add(name);

  @override
  void dispose() {
    isClosed = true;
    _recorder.record(name);
  }
}

class ClosingAsyncStep implements CobaltBootstrapStep, AsyncDisposable {
  ClosingAsyncStep(this.name) : _recorder = recorder;

  @override
  final String name;

  final DisposeRecorder _recorder;

  @override
  void run() => bootLog.add(name);

  @override
  Future<void> dispose() async => _recorder.record(name);
}

class FailingStep implements CobaltBootstrapStep {
  @override
  String get name => 'ffi';

  @override
  void run() => throw ArgumentError('native library missing');
}

class RootBuilder implements CobaltScopeBuilder {
  const RootBuilder();

  @override
  void build(CobaltScope scope) {
    bootLog.add('build');
    scope.registerLazySingleton<Logger>(const LoggerFactory());
    scope.registerAsyncSingleton<SlowService>(const SlowFactory('db', 0));
  }
}

void main() {
  setUp(() {
    resetLogs();
    bootLog.clear();
  });

  test('bootstrap steps run sequentially in declared order', () async {
    final scope = await CobaltApplication.start(
      root: const RootBuilder(),
      bootstrap: [
        RecordingStep('binding', millis: 30),
        SyncStep('ffi'),
        RecordingStep('prefs', millis: 10),
      ],
    );

    expect(bootLog, ['binding', 'ffi', 'prefs', 'build']);
    await scope.dispose();
  });

  test('the whole bootstrap finishes before the graph is built', () async {
    final scope = await CobaltApplication.start(
      root: const RootBuilder(),
      bootstrap: [SyncStep('phase0')],
    );

    expect(bootLog.indexOf('phase0'), lessThan(bootLog.indexOf('build')));
    expect(initLog, ['db']);
    await scope.dispose();
  });

  test('a failing step names itself and aborts the start', () async {
    await expectLater(
      CobaltApplication.start(
        root: const RootBuilder(),
        bootstrap: [SyncStep('binding'), FailingStep(), SyncStep('never')],
      ),
      throwsA(
        isA<CobaltBootstrapError>()
            .having((e) => e.step, 'step', 'ffi')
            .having((e) => e.cause, 'cause', isA<ArgumentError>()),
      ),
    );

    expect(bootLog, ['binding']);
  });

  test('the returned scope is active and usable', () async {
    final scope = await CobaltApplication.start(root: const RootBuilder());

    expect(scope.state, CobaltScopeState.active);
    expect(scope.get<Logger>(), isNotNull);
    expect(scope.get<SlowService>().label, 'db');

    await scope.dispose();
    expect(scope.state, CobaltScopeState.disposed);
  });

  group('the root scope owns the bootstrap steps', () {
    test('a step that holds a resource is closed with the scope', () async {
      final step = ClosingStep('binding');
      final scope = await CobaltApplication.start(
        root: const RootBuilder(),
        bootstrap: [step],
      );

      expect(step.isClosed, isFalse);
      await scope.dispose();

      expect(step.isClosed, isTrue);
    });

    test('steps are released after everything built on top of them', () async {
      final scope = await CobaltApplication.start(
        root: const RootBuilder(),
        bootstrap: [ClosingStep('binding')],
      );
      scope.registerSingleton(Recorder('service'));

      await scope.dispose();

      expect(
        recorder.entries,
        ['service', 'binding'],
        reason: 'bootstrap set up the platform, so it is torn down last',
      );
    });

    test('an async step is awaited during teardown', () async {
      final scope = await CobaltApplication.start(
        root: const RootBuilder(),
        bootstrap: [ClosingAsyncStep('binding')],
      );

      await scope.dispose();

      expect(recorder.entries, ['binding']);
    });

    test('a step with nothing to release costs the scope nothing', () async {
      final scope = await CobaltApplication.start(
        root: const RootBuilder(),
        bootstrap: [SyncStep('plain')],
      );

      await scope.dispose();

      expect(recorder.entries, isEmpty);
    });
  });

  group('a bootstrap failure', () {
    test('releases the steps that already ran, in reverse', () async {
      await expectLater(
        CobaltApplication.start(
          root: const RootBuilder(),
          bootstrap: [
            ClosingStep('first'),
            ClosingStep('second'),
            FailingStep(),
          ],
        ),
        throwsA(isA<CobaltBootstrapError>()),
      );

      expect(recorder.entries, ['second', 'first']);
    });

    test('leaves nothing running when the very first step fails', () async {
      await expectLater(
        CobaltApplication.start(
          root: const RootBuilder(),
          bootstrap: [FailingStep(), ClosingStep('never')],
        ),
        throwsA(isA<CobaltBootstrapError>()),
      );

      expect(recorder.entries, isEmpty);
      expect(bootLog, isEmpty);
    });
  });

  group('adopt', () {
    test('ties an arbitrary object to the scope lifetime', () async {
      final scope = cobaltTestRoot();
      final adopted = scope.adopt(Recorder('adopted'));

      await scope.dispose();

      expect(recorder.entries, ['adopted']);
      expect(adopted, isA<Recorder>());
    });

    test('does not make the object resolvable', () async {
      final scope = cobaltTestRoot()..adopt(Recorder('adopted'));

      expect(scope.isRegistered<Recorder>(), isFalse);
      await scope.dispose();
    });

    test('keeps ordering with everything else the scope owns', () async {
      final scope = cobaltTestRoot()..adopt(Recorder('first'));
      scope.registerSingleton(Recorder('second'), name: 'second');

      await scope.dispose();

      expect(recorder.entries, ['second', 'first']);
    });

    test('a non-disposable is returned but not retained', () async {
      final scope = cobaltTestRoot();
      final value = scope.adopt(const Clock());

      await scope.dispose();

      expect(value, isA<Clock>());
      expect(recorder.entries, isEmpty);
    });

    test('is rejected once the scope is gone', () async {
      final scope = cobaltTestRoot();
      await scope.dispose();

      expect(
        () => scope.adopt(Recorder('late')),
        throwsA(isA<CobaltScopeStateError>()),
      );
    });
  });
}

class Clock {
  const Clock();
}
