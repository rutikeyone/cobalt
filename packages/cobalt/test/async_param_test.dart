import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class Document implements Disposable {
  Document(this.id, {this.source = 'real'});

  final int id;
  final String source;
  var isClosed = false;

  @override
  void dispose() => isClosed = true;
}

final class Store {
  Store(this.label);

  final String label;
}

final class Index {}

final class _Kinds extends CobaltObserver {
  final kinds = <CobaltRegistrationKind>[];

  @override
  void onInstanceCreated(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
  }) => kinds.add(kind);
}

const _deadlock = Duration(seconds: 2);

void main() {
  CobaltScope documents({List<CobaltObserver> observers = const []}) =>
      cobaltTestRoot(observers: observers)
        ..registerLazySingleton<Store>(FnFactory((_) => Store('root')))
        ..registerAsyncParamFactory<Document, int>(
          AsyncFnParamFactory((resolver, id) async {
            await Future<void>.delayed(Duration.zero);
            return Document(id, source: resolver.get<Store>().label);
          }),
        );

  group('building from a value', () {
    test('awaits the factory with the value the caller passes', () async {
      final scope = documents();

      final document = await scope.getAsyncWithParam<Document, int>(7);

      expect(document.id, 7);
      expect(document.source, 'root');
    });

    test('every call builds a new instance the scope does not keep', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncParamFactory<Document, int>(
          AsyncFnParamFactory((_, id) async => Document(id)),
        );

      final first = await scope.getAsyncWithParam<Document, int>(1);
      final again = await scope.getAsyncWithParam<Document, int>(1);
      await scope.dispose();

      expect(first, isNot(same(again)));
      expect(first.isClosed, isFalse, reason: 'the caller owns it');
    });

    test('runs on the scope that owns the registration', () async {
      final root = documents();
      final child = root.push('screen')
        ..registerLazySingleton<Store>(FnFactory((_) => Store('child')));

      final document = await child.getAsyncWithParam<Document, int>(3);

      expect(document.source, 'root');
    });

    test('a factory can await a lazy registration', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Store>(
          AsyncFnFactory((_) async => Store('lazy')),
        )
        ..registerAsyncParamFactory<Document, int>(
          AsyncFnParamFactory(
            (resolver, id) async =>
                Document(id, source: (await resolver.getAsync<Store>()).label),
          ),
        );

      final document = await scope.getAsyncWithParam<Document, int>(1);

      expect(document.source, 'lazy');
    });

    test('may be registered after init', () async {
      final scope = cobaltTestRoot();
      await scope.init();

      scope.registerAsyncParamFactory<Document, int>(
        AsyncFnParamFactory((_, id) async => Document(id)),
      );

      expect((await scope.getAsyncWithParam<Document, int>(2)).id, 2);
    });

    test(
      'a synchronous parameterized registration resolves here too',
      () async {
        final scope = cobaltTestRoot()
          ..registerParamFactory<Store, String>(
            FnParamFactory((_, label) => Store(label)),
          );

        expect((await scope.getAsyncWithParam<Store, String>('x')).label, 'x');
      },
    );

    test('a value of a subtype is accepted', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncParamFactory<Store, Object>(
          AsyncFnParamFactory((_, value) async => Store('$value')),
        );

      expect((await scope.getAsyncWithParam<Store, String>('s')).label, 's');
    });
  });

  group('what it refuses', () {
    test('a synchronous resolve names the async form', () {
      final scope = documents();

      expect(
        () => scope.getWithParam<Document, int>(1),
        throwsA(isA<CobaltAsyncParamError>()),
      );
      expect(
        () => scope.get<Document>(),
        throwsA(
          isA<CobaltParamRequiredError>().having(
            (e) => e.message,
            'message',
            contains('getAsyncWithParam'),
          ),
        ),
      );
      expect(
        scope.getAsync<Document>(),
        throwsA(isA<CobaltParamRequiredError>()),
      );
    });

    test('a value of the wrong type', () {
      expect(
        documents().getAsyncWithParam<Document, String>('seven'),
        throwsA(isA<CobaltParamTypeError>()),
      );
    });

    test('a registration that takes no value', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Store>(FnFactory((_) => Store('x')));

      expect(
        scope.getAsyncWithParam<Store, int>(1),
        throwsA(isA<CobaltNotParameterizedError>()),
      );
    });

    test('a key nothing registers', () {
      expect(
        cobaltTestRoot().getAsyncWithParam<Document, int>(1),
        throwsA(isA<CobaltNotRegisteredError>()),
      );
    });

    test('a build that asks for its own key is a cycle, not a hang', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncParamFactory<Document, int>(
          AsyncFnParamFactory((resolver, id) async {
            await Future<void>.delayed(Duration.zero);
            if (id >= 20) return Document(id);
            return resolver.getAsyncWithParam<Document, int>(id + 1);
          }),
        );

      await expectLater(
        scope.getAsyncWithParam<Document, int>(1).timeout(_deadlock),
        throwsA(isA<CobaltCycleError>()),
      );
    });

    test('warmUp has nothing to build ahead of time', () {
      expect(
        documents().warmUp(const [CobaltKey(Document)]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('beside the rest of the runtime', () {
    test('an override replaces it', () async {
      final scope = cobaltTestRoot(
        overrides: [
          CobaltAsyncParamOverride<Document, int>(
            AsyncFnParamFactory((_, id) async => Document(id, source: 'fake')),
          ),
        ],
      )..runBuilder(_DocumentScope());

      final document = await scope.getAsyncWithParam<Document, int>(4);

      expect(document.source, 'fake');
      expect(scope.overriddenKeys, [const CobaltKey(Document)]);
    });

    test('each build is decorated', () async {
      var wrapped = 0;
      final scope = documents()
        ..decorate<Document>(
          FnDecorator((inner, _) {
            wrapped++;
            return inner;
          }),
        );

      await scope.getAsyncWithParam<Document, int>(1);
      await scope.getAsyncWithParam<Document, int>(2);

      expect(wrapped, 2);
    });

    test('observers see the kind', () async {
      final kinds = _Kinds();
      final scope = documents(observers: [kinds]);

      await scope.getAsyncWithParam<Document, int>(1);

      expect(kinds.kinds, contains(CobaltRegistrationKind.asyncParameterized));
    });

    test('introspection names and builds it by key', () async {
      final scope = documents();
      const key = CobaltKey(Document);

      expect(scope.debugKindOf(key), CobaltRegistrationKind.asyncParameterized);
      expect(
        await scope.debugResolveWithParamAsync(key, 9),
        isA<Document>().having((d) => d.id, 'id', 9),
      );
      expect(
        await scope.debugResolveWithParamAsync(const CobaltKey(Index), 9),
        isNull,
      );
      expect(
        () => scope.debugResolveWithParam(key, 9),
        throwsA(isA<CobaltAsyncParamError>()),
      );
    });
  });
}

final class _DocumentScope implements CobaltScopeBuilder {
  @override
  void build(CobaltScope scope) =>
      scope.registerAsyncParamFactory<Document, int>(
        AsyncFnParamFactory((_, id) async => Document(id)),
      );
}
