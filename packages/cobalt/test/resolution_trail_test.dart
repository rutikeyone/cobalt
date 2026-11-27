import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

class Missing {}

class Ready {}

class Api {
  Api(this.repository);

  final Object repository;
}

class Repository {
  Repository(this.missing);

  final Object missing;
}

void main() {
  group('a failure inside a factory', () {
    test('names the registration that asked for it', () {
      final scope = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Repository>(
          FnFactory((resolver) => Repository(resolver.get<Missing>())),
        );

      expect(
        () => scope.get<Repository>(),
        throwsA(
          isA<CobaltNotRegisteredError>().having(
            (e) => e.toString(),
            'message',
            contains('Resolving: Repository -> Missing'),
          ),
        ),
      );
    });

    test('names every step of a chain, outermost first', () {
      final scope = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Api>(
          FnFactory((resolver) => Api(resolver.get<Repository>())),
        )
        ..registerLazySingleton<Repository>(
          FnFactory((resolver) => Repository(resolver.get<Missing>())),
        );

      expect(
        () => scope.get<Api>(),
        throwsA(
          isA<CobaltNotRegisteredError>().having(
            (e) => e.toString(),
            'message',
            contains('Resolving: Api -> Repository -> Missing'),
          ),
        ),
      );
    });

    test('carries the trail as keys, not only as prose', () {
      final scope = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Repository>(
          FnFactory((resolver) => Repository(resolver.get<Missing>())),
        );

      try {
        scope.get<Repository>();
        fail('the missing registration should have thrown');
      } on CobaltNotRegisteredError catch (error) {
        expect(error.resolving.map((key) => key.type), [Repository]);
        expect(error.key.type, Missing);
      }
    });

    test('an async singleton asked for too early names the asker too', () {
      final scope = cobaltTestRoot(name: 'app')
        ..registerAsyncSingleton<Ready>(AsyncFnFactory((_) async => Ready()))
        ..registerLazySingleton<Repository>(
          FnFactory((resolver) => Repository(resolver.get<Ready>())),
        );

      expect(
        () => scope.get<Repository>(),
        throwsA(
          isA<CobaltNotReadyError>().having(
            (e) => e.toString(),
            'message',
            contains('Resolving: Repository -> Ready'),
          ),
        ),
      );
    });
  });

  group('a failure outside one', () {
    test('asking from the top has no trail to report', () {
      final scope = cobaltTestRoot(name: 'app');

      expect(
        () => scope.get<Missing>(),
        throwsA(
          isA<CobaltNotRegisteredError>().having(
            (e) => e.toString(),
            'message',
            isNot(contains('Resolving:')),
          ),
        ),
      );
    });

    /// The reason the trail is built by `guard` alone.
    ///
    /// Both keys of a level are under construction at once, and phase 1 stays
    /// off the tracker. Reading them as a chain would print a caller that
    /// never called.
    test('a parallel init level does not invent a caller', () async {
      final scope = cobaltTestRoot(name: 'app')
        ..registerAsyncSingleton<Ready>(
          AsyncFnFactory((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return Ready();
          }),
        )
        ..registerAsyncSingleton<Api>(
          AsyncFnFactory((resolver) async => Api(resolver.get<Missing>())),
        );

      await expectLater(
        scope.init(),
        throwsA(
          isA<CobaltNotRegisteredError>()
              .having((e) => e.toString(), 'message', isNot(contains('Ready')))
              .having((e) => e.resolving, 'resolving', isEmpty),
        ),
      );
    });
  });
}
