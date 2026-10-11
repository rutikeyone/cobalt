import 'package:cobalt/cobalt.dart';
import 'package:test/test.dart';

import 'support.dart';

class _SessionScope implements CobaltScopeBuilder {
  const _SessionScope();

  @override
  void build(CobaltScope scope) => scope
    ..registerSingleton<Recorder>(Recorder('session'))
    ..registerLazySingleton<ApiClient>(const ApiClientFactory());
}

class _FailingBuilder implements CobaltScopeBuilder {
  const _FailingBuilder();

  @override
  void build(CobaltScope scope) {
    scope.registerSingleton<Recorder>(Recorder('built before the failure'));
    throw StateError('builder failed');
  }
}

class _FailingInit implements CobaltScopeBuilder {
  const _FailingInit();

  @override
  void build(CobaltScope scope) => scope
    ..registerSingleton<Recorder>(Recorder('built before init'))
    ..registerAsyncSingleton<SlowService>(const _ThrowingFactory());
}

class _ThrowingFactory implements CobaltAsyncFactory<SlowService> {
  const _ThrowingFactory();

  @override
  Future<SlowService> create(CobaltResolver resolver) async =>
      throw StateError('init failed');
}

class _NeverEnding implements CobaltScopeBuilder {
  const _NeverEnding();

  @override
  void build(CobaltScope scope) =>
      scope.registerAsyncSingleton<SlowService>(const _NeverFactory());
}

class _NeverFactory implements CobaltAsyncFactory<SlowService> {
  const _NeverFactory();

  @override
  Future<SlowService> create(CobaltResolver resolver) =>
      Future.delayed(const Duration(hours: 1), () => SlowService('never'));
}

final class _Pushes extends CobaltObserver {
  final seen = <String>[];

  @override
  void onScopePushed(CobaltScopeRef scope) => seen.add('pushed:$scope');
}

void main() {
  setUp(resetLogs);

  test('returns an active child that resolves through its parent', () async {
    final app = CobaltScope.root(name: 'app')
      ..registerLazySingleton<Logger>(const LoggerFactory());

    final session = await app.open('session', const _SessionScope());

    expect(session.state, CobaltScopeState.active);
    expect(session.name, 'session');
    expect(app.children, [session]);
    expect(session.get<ApiClient>().logger, same(app.get<Logger>()));

    await session.dispose();
    expect(recorder.entries, ['ApiClient', 'session']);
  });

  test('a builder that throws leaves nothing behind', () async {
    final app = CobaltScope.root(name: 'app');

    await expectLater(
      app.open('session', const _FailingBuilder()),
      throwsA(isA<StateError>()),
    );

    expect(app.children, isEmpty);
    expect(recorder.entries, ['built before the failure']);
  });

  test('an init that throws leaves nothing behind', () async {
    final app = CobaltScope.root(name: 'app');

    await expectLater(
      app.open('session', const _FailingInit()),
      throwsA(isA<StateError>()),
    );

    expect(app.children, isEmpty);
    expect(recorder.entries, ['built before init']);
  });

  test('an override nothing claims leaves nothing behind', () async {
    final app = CobaltScope.root(name: 'app');

    await expectLater(
      app.open(
        'session',
        const _SessionScope(),
        overrides: [CobaltOverride<Logger>.value(Logger())],
      ),
      throwsA(isA<CobaltOverrideError>()),
    );

    expect(app.children, isEmpty);
  });

  test('initTimeout bounds init', () async {
    final app = CobaltScope.root(name: 'app');

    await expectLater(
      app.open(
        'session',
        const _NeverEnding(),
        initTimeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<CobaltInitTimeoutError>()),
    );

    expect(app.children, isEmpty);
  });

  test('observers watch the child from the moment it is pushed', () async {
    final app = CobaltScope.root(name: 'app');
    final events = _Pushes();

    final session = await app.open(
      'session',
      const _SessionScope(),
      observers: [events],
    );

    expect(events.seen, ['pushed:app/session']);
    await session.dispose();
  });
}
