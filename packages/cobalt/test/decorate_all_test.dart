import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

abstract interface class Api {
  List<String> get trail;
}

final class RealApi implements Api {
  RealApi(this.label);

  final String label;

  @override
  List<String> get trail => [label];
}

final class Wrapped implements Api {
  Wrapped(this.label, this.inner);

  final String label;
  final Api inner;

  @override
  List<String> get trail => [label, ...inner.trail];
}

final class Clock {
  const Clock();
}

FnDecorator<Api> wrapping(String label) =>
    FnDecorator((inner, _) => Wrapped(label, inner));

final class _Graph implements CobaltScopeBuilder {
  const _Graph(this.build_);

  final void Function(CobaltScope scope) build_;

  @override
  void build(CobaltScope scope) => build_(scope);
}

void main() {
  CobaltScope apis() => cobaltTestRoot()
    ..registerLazySingleton<Api>(FnFactory((_) => RealApi('default')))
    ..registerLazySingleton<Api>(
      FnFactory((_) => RealApi('auth')),
      name: 'auth',
    )
    ..registerFactory<Api>(FnFactory((_) => RealApi('cdn')), name: 'cdn');

  group('wrapping every registration of a type', () {
    test('named and unnamed alike, whatever their lifetime', () {
      final scope = apis()..decorateAll<Api>(wrapping('logged'));

      expect(scope.get<Api>().trail, ['logged', 'default']);
      expect(scope.get<Api>(name: 'auth').trail, ['logged', 'auth']);
      expect(scope.get<Api>(name: 'cdn').trail, ['logged', 'cdn']);
    });

    test('a retained one is decorated once and shared', () {
      final scope = apis()..decorateAll<Api>(wrapping('logged'));

      expect(
        identical(scope.get<Api>(name: 'auth'), scope.get<Api>(name: 'auth')),
        isTrue,
      );
    });

    test('a transient one is decorated on every build', () {
      var wrapped = 0;
      final scope = apis()
        ..decorateAll<Api>(
          FnDecorator((inner, _) {
            wrapped++;
            return inner;
          }),
        );

      scope
        ..get<Api>(name: 'cdn')
        ..get<Api>(name: 'cdn');

      expect(wrapped, 2);
    });

    test('a registration added after it is wrapped too', () {
      final scope = cobaltTestRoot()
        ..decorateAll<Api>(wrapping('logged'))
        ..registerLazySingleton<Api>(FnFactory((_) => RealApi('late')));

      expect(scope.get<Api>().trail, ['logged', 'late']);
    });

    test('getAll hands out every one decorated', () {
      final scope = apis()..decorateAll<Api>(wrapping('logged'));

      expect(scope.getAll<Api>().map((api) => api.trail.first), [
        'logged',
        'logged',
        'logged',
      ]);
    });

    test('an async registration of the type is wrapped as well', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Api>(
          AsyncFnFactory((_) async => RealApi('lazy')),
        )
        ..registerAsyncFactory<Api>(
          AsyncFnFactory((_) async => RealApi('fresh')),
          name: 'fresh',
        )
        ..decorateAll<Api>(wrapping('logged'));

      expect((await scope.getAsync<Api>()).trail, ['logged', 'lazy']);
      expect((await scope.getAsync<Api>(name: 'fresh')).trail, [
        'logged',
        'fresh',
      ]);
    });

    test('an override is wrapped like what it replaced', () {
      final scope =
          cobaltTestRoot(
            overrides: [
              CobaltOverride<Api>.value(RealApi('fake'), name: 'auth'),
            ],
          )..runBuilder(
            _Graph(
              (scope) => scope
                ..registerLazySingleton<Api>(
                  FnFactory((_) => RealApi('auth')),
                  name: 'auth',
                )
                ..decorateAll<Api>(wrapping('logged')),
            ),
          );

      expect(scope.get<Api>(name: 'auth').trail, ['logged', 'fake']);
    });

    test('another type is left alone', () {
      final scope = apis()
        ..registerSingleton<Clock>(const Clock())
        ..decorateAll<Api>(wrapping('logged'));

      expect(scope.get<Clock>(), same(const Clock()));
    });
  });

  group('one order with decorate', () {
    test('whatever was added first is innermost', () {
      final scope = apis()
        ..decorate<Api>(wrapping('retry'), name: 'auth')
        ..decorateAll<Api>(wrapping('logged'))
        ..decorate<Api>(wrapping('cache'), name: 'auth');

      expect(scope.get<Api>(name: 'auth').trail, [
        'cache',
        'logged',
        'retry',
        'auth',
      ]);
      expect(scope.get<Api>().trail, ['logged', 'default']);
    });

    test('introspection names both kinds in that order', () {
      final scope = apis()
        ..decorateAll<Api>(wrapping('x'), debugLabel: 'Logged')
        ..decorate<Api>(wrapping('y'), name: 'auth', debugLabel: 'Cached');

      expect(scope.debugDecoratorsOf(const CobaltKey(Api, name: 'auth')), [
        'Logged',
        'Cached',
      ]);
      expect(scope.debugDecoratorsOf(const CobaltKey(Api)), ['Logged']);
    });

    test('several of the type apply in the order added', () {
      final scope = apis()
        ..decorateAll<Api>(wrapping('inner'))
        ..decorateAll<Api>(wrapping('outer'));

      expect(scope.get<Api>().trail, ['outer', 'inner', 'default']);
    });
  });

  group('what it refuses', () {
    test('a type one of whose keys was already resolved', () {
      final scope = apis()..get<Api>(name: 'auth');

      expect(
        () => scope.decorateAll<Api>(wrapping('logged')),
        throwsA(
          isA<CobaltDecoratorError>().having(
            (e) => e.key,
            'key',
            const CobaltKey(Api, name: 'auth'),
          ),
        ),
      );
    });

    test('a type the scope does not register, naming the owner', () {
      final app = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Api>(
          FnFactory((_) => RealApi('auth')),
          name: 'auth',
        );
      final child = app.pushForTest('screen');

      expect(
        () => child.runBuilder(
          _Graph((scope) => scope.decorateAll<Api>(wrapping('x'))),
        ),
        throwsA(
          isA<CobaltDecoratorError>()
              .having((e) => e.owner, 'owner', 'app')
              .having((e) => e.message, 'message', contains('every Api')),
        ),
      );
    });

    test('a type nothing registers anywhere', () {
      expect(
        () => cobaltTestRoot().runBuilder(
          _Graph((scope) => scope.decorateAll<Api>(wrapping('x'))),
        ),
        throwsA(
          isA<CobaltDecoratorError>()
              .having((e) => e.owner, 'owner', isNull)
              .having((e) => e.key, 'key', const CobaltKey(Api)),
        ),
      );
    });

    test('a decorator that resolves its own type is a cycle', () {
      final scope = apis()
        ..decorateAll<Api>(
          FnDecorator((inner, resolver) {
            resolver.get<Api>(name: 'auth');
            return inner;
          }),
        );

      expect(
        () => scope.get<Api>(name: 'auth'),
        throwsA(isA<CobaltCycleError>()),
      );
    });
  });
}
