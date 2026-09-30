import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

class Slow implements Disposable {
  var closed = false;

  @override
  void dispose() => closed = true;
}

class Fast {}

class Opened implements Disposable {
  var closed = false;

  @override
  void dispose() => closed = true;
}

class After {}

final class _Builder implements CobaltScopeBuilder {
  const _Builder(this.build_);
  final void Function(CobaltScope scope) build_;

  @override
  void build(CobaltScope scope) => build_(scope);
}

final class _Failures extends CobaltObserver {
  final failed = <Object>[];

  @override
  void onScopeInitFailed(
    CobaltScopeRef scope,
    Object error,
    StackTrace stackTrace,
  ) => failed.add(error);
}

void main() {
  late Completer<Slow> slow;
  setUp(() => slow = Completer<Slow>());

  const timeout = Duration(milliseconds: 30);

  test('names what had not been built when time ran out', () async {
    final observer = _Failures();
    final scope = cobaltTestRoot(name: 'app', observers: [observer])
      ..registerAsyncSingleton<Fast>(AsyncFnFactory((_) async => Fast()))
      ..registerAsyncSingleton<Slow>(AsyncFnFactory((_) => slow.future))
      ..registerAsyncSingleton<After>(
        AsyncFnFactory((_) async => After()),
        dependsOn: {const CobaltKey(Slow)},
      );

    await expectLater(
      scope.init(timeout: timeout),
      throwsA(
        isA<CobaltInitTimeoutError>()
            .having((e) => e.scopeName, 'scopeName', 'app')
            .having((e) => e.timeout, 'timeout', timeout)
            .having((e) => e.pending, 'pending', [
              const CobaltKey(Slow),
              const CobaltKey(After),
            ]),
      ),
    );
    expect(observer.failed.single, isA<CobaltInitTimeoutError>());
  });

  test('a graph that finishes in time is not affected', () async {
    final scope = cobaltTestRoot()
      ..registerAsyncSingleton<Fast>(AsyncFnFactory((_) async => Fast()));

    await scope.init(timeout: const Duration(seconds: 5));

    expect(scope.state, CobaltScopeState.active);
    expect(scope.get<Fast>(), isA<Fast>());
  });

  test(
    'a build that arrives late is released, and nothing after it starts',
    () async {
      var afterBuilt = false;
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<Slow>(AsyncFnFactory((_) => slow.future))
        ..registerAsyncSingleton<After>(
          AsyncFnFactory((_) async {
            afterBuilt = true;
            return After();
          }),
          dependsOn: {const CobaltKey(Slow)},
        );

      await expectLater(
        scope.init(timeout: timeout),
        throwsA(isA<CobaltInitTimeoutError>()),
      );
      await scope.dispose();

      final late = Slow();
      slow.complete(late);
      await pumpEventQueue();

      expect(late.closed, isTrue, reason: 'nobody else will ever close it');
      expect(afterBuilt, isFalse, reason: 'the level after it never started');
    },
  );

  test('CobaltApplication.start disposes a root that timed out', () async {
    final opened = Opened();
    await expectLater(
      CobaltApplication.start(
        root: _Builder(
          (scope) => scope
            ..registerAsyncSingleton<Opened>(
              AsyncFnFactory((_) async => opened),
            )
            ..registerAsyncSingleton<Slow>(AsyncFnFactory((_) => slow.future)),
        ),
        initTimeout: timeout,
      ),
      throwsA(isA<CobaltInitTimeoutError>()),
    );

    expect(opened.closed, isTrue, reason: 'what was built is released');
  });
}
