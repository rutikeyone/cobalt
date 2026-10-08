import 'package:cobalt/cobalt.dart';
import 'package:cobalt/src/errors/troubleshooting_link.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

class Config {}

class Api {}

class Repository {
  Repository(this.config);

  final Config config;
}

class TooEager implements CobaltScopeBuilder {
  const TooEager();

  @override
  void build(CobaltScope scope) {
    scope
      ..registerSingleton<Repository>(Repository(scope.get<Config>()))
      ..registerLazySingleton<Config>(FnFactory((_) => Config()));
  }
}

CobaltNotRegisteredError failureOf(void Function() resolve) {
  try {
    resolve();
  } on CobaltNotRegisteredError catch (error) {
    return error;
  }
  fail('the lookup should have thrown CobaltNotRegisteredError');
}

void main() {
  group('the first sentence', () {
    test('is unchanged', () {
      final app = cobaltTestRoot(name: 'app');
      app.push('session').registerSingleton<Config>(Config());

      final error = failureOf(app.get<Config>);

      expect(
        error.message,
        startsWith('Config is not registered in scope "app" or its ancestors.'),
      );
    });

    test('the troubleshooting link is still last', () {
      final app = cobaltTestRoot(name: 'app')
        ..registerSingleton<Api>(Api(), name: 'fake');

      final error = failureOf(app.get<Api>);

      expect(
        error.toString(),
        endsWith('\nSee $troubleshootingPage#cobaltnotregisterederror'),
      );
      expect(error.message, isNot(contains(troubleshootingPage)));
    });

    test('the hints come after the resolution trail', () {
      final app = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Repository>(
          FnFactory((resolver) => Repository(resolver.get<Config>())),
        );

      final error = failureOf(app.get<Repository>);

      expect(
        error.message,
        'Config is not registered in scope "app" or its ancestors. '
        'Resolving: Repository -> Config. Nothing in this scope tree '
        'registers Config. Register it, or if it is a @cobaltInject class, '
        'run build_runner again.',
      );
    });
  });

  group('registered elsewhere', () {
    test('names a child that registers the key', () {
      final app = cobaltTestRoot(name: 'app');
      app.push('session').registerSingleton<Config>(Config());

      final error = failureOf(app.get<Config>);

      expect(error.registeredElsewhere, ['session']);
      expect(
        error.message,
        'Config is not registered in scope "app" or its ancestors. It is '
        'registered in scope "session", which is not above "app": resolution '
        'walks up, never down.',
      );
    });

    test('names a sibling that registers the key', () {
      final app = cobaltTestRoot(name: 'app');
      app.push('a').registerSingleton<Config>(Config());
      final b = app.push('b');

      final error = failureOf(b.get<Config>);

      expect(error.registeredElsewhere, ['a']);
      expect(
        error.message,
        contains(
          ' It is registered in scope "a", which is not above "b": '
          'resolution walks up, never down.',
        ),
      );
    });

    test('names several scopes in one sentence', () {
      final app = cobaltTestRoot(name: 'app');
      app.push('a').registerSingleton<Config>(Config());
      app.push('b').registerSingleton<Config>(Config());

      final error = failureOf(app.get<Config>);

      expect(
        error.message,
        contains(
          ' It is registered in scopes "a", "b", which are not above "app": '
          'resolution walks up, never down.',
        ),
      );
    });

    test('stops at three, depth first from the root', () {
      final app = cobaltTestRoot(name: 'app');
      app.push('one').push('one.inner').registerSingleton<Config>(Config());
      app.push('two').registerSingleton<Config>(Config());
      app.push('three').registerSingleton<Config>(Config());
      app.push('four').registerSingleton<Config>(Config());
      app.children.first.registerSingleton<Config>(Config());

      final error = failureOf(app.get<Config>);

      expect(error.registeredElsewhere, ['one', 'one.inner', 'two']);
    });

    test('a disposed scope no longer counts', () async {
      final app = cobaltTestRoot(name: 'app');
      final session = app.push('session')..registerSingleton<Config>(Config());
      await session.dispose();

      final error = failureOf(app.get<Config>);

      expect(error.registeredElsewhere, isEmpty);
      expect(error.message, contains('Nothing in this scope tree'));
    });
  });

  group('same type', () {
    test('lists the visible keys of the type under other names', () {
      final app = cobaltTestRoot(name: 'app')
        ..registerSingleton<Api>(Api(), name: 'fake')
        ..registerSingleton<Api>(Api());
      final screen = app.push('screen');

      final error = failureOf(() => screen.get<Api>(name: 'real'));

      expect(error.sameType, [
        const CobaltKey(Api),
        const CobaltKey(Api, name: 'fake'),
      ]);
      expect(
        error.message,
        'Api(real) is not registered in scope "screen" or its ancestors. '
        'The same type is registered as Api, Api(fake).',
      );
    });

    test('leaves out keys only a child can see', () {
      final app = cobaltTestRoot(name: 'app');
      app.push('session').registerSingleton<Api>(Api(), name: 'fake');

      final error = failureOf(app.get<Api>);

      expect(error.sameType, isEmpty);
      expect(error.message, isNot(contains('The same type')));
    });
  });

  test('both hints together, and nothing else', () {
    final app = cobaltTestRoot(name: 'app')..registerSingleton<Api>(Api());
    app.push('session').registerSingleton<Api>(Api(), name: 'real');

    final error = failureOf(() => app.get<Api>(name: 'real'));

    expect(
      error.message,
      'Api(real) is not registered in scope "app" or its ancestors. It is '
      'registered in scope "session", which is not above "app": resolution '
      'walks up, never down. The same type is registered as Api.',
    );
  });

  group('nothing registers it', () {
    test('says so, and how to fix it', () {
      final app = cobaltTestRoot(name: 'app');

      final error = failureOf(app.get<Config>);

      expect(error.registeredElsewhere, isEmpty);
      expect(error.sameType, isEmpty);
      expect(
        error.message,
        endsWith(
          ' Nothing in this scope tree registers Config. Register it, or if '
          'it is a @cobaltInject class, run build_runner again.',
        ),
      );
    });

    test('is not claimed while a builder is still running', () {
      final app = cobaltTestRoot(name: 'app');

      final error = failureOf(() => app.runBuilder(const TooEager()));

      expect(error.whileBuilding, isTrue);
      expect(error.message, contains('still being built'));
      expect(error.message, isNot(contains('Nothing in this scope tree')));
    });
  });

  group('every lookup carries the hints', () {
    test('getAsync', () async {
      final app = cobaltTestRoot(name: 'app');
      app.push('session').registerSingleton<Config>(Config());

      await expectLater(
        app.getAsync<Config>(),
        throwsA(
          isA<CobaltNotRegisteredError>().having(
            (error) => error.registeredElsewhere,
            'registeredElsewhere',
            ['session'],
          ),
        ),
      );
    });

    test('getWithParam', () {
      final app = cobaltTestRoot(name: 'app')
        ..registerParamFactory<Api, int>(
          FnParamFactory((_, _) => Api()),
          name: 'fake',
        );

      final error = failureOf(() => app.getWithParam<Api, int>(1));

      expect(error.sameType, [const CobaltKey(Api, name: 'fake')]);
    });

    test('getAsyncWithParam', () async {
      final app = cobaltTestRoot(name: 'app');

      await expectLater(
        app.getAsyncWithParam<Api, int>(1),
        throwsA(
          isA<CobaltNotRegisteredError>().having(
            (error) => error.message,
            'message',
            contains('Nothing in this scope tree registers Api.'),
          ),
        ),
      );
    });

    test('warmUp', () async {
      final app = cobaltTestRoot(name: 'app');
      app.push('session').registerSingleton<Config>(Config());

      await expectLater(
        app.warmUp([const CobaltKey(Config)]),
        throwsA(
          isA<CobaltNotRegisteredError>().having(
            (error) => error.registeredElsewhere,
            'registeredElsewhere',
            ['session'],
          ),
        ),
      );
    });
  });
}
