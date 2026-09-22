import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

String _flat(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('a lazy async class', () {
    test('is registered with registerLazyAsyncSingleton', () {
      final source = generate([declare('SearchEngine', isLazyAsync: true)]);

      expect(
        source,
        contains('registerLazyAsyncSingleton<_i137.SearchEngine>'),
      );
      expect(source, isNot(contains('registerAsyncSingleton')));
    });

    test('still awaits init() in its factory', () {
      final source = generate([declare('SearchEngine', isLazyAsync: true)]);

      expect(source, contains('CobaltAsyncFactory<_i137.SearchEngine>'));
      expect(source, contains('await instance.init()'));
    });

    test('awaits a lazy dependency and reads the rest synchronously', () {
      final source = generate([
        declare('Clock'),
        declare('Model', isLazyAsync: true),
        declare(
          'SearchEngine',
          isLazyAsync: true,
          constructor: [dep('Model'), dep('Clock')],
        ),
      ]);

      final flat = _flat(source);
      expect(flat, contains('await resolver.getAsync<_i137.Model>()'));
      expect(flat, contains('resolver.get<_i137.Clock>()'));
      expect(flat, isNot(contains('resolver.get<_i137.Model>()')));
    });

    test('an optional lazy dependency is awaited only when registered', () {
      final source = generate([
        declare('Model', isLazyAsync: true),
        declare(
          'SearchEngine',
          isLazyAsync: true,
          constructor: [dep('Model', isNullable: true)],
        ),
      ]);

      expect(
        _flat(source),
        contains(
          'resolver.isRegistered<_i137.Model>() '
          '? await resolver.getAsync<_i137.Model>() : null',
        ),
      );
    });

    test('is not given a derived dependsOn', () {
      final source = generate([
        declare('Database', isAsyncInit: true),
        provide(
          'Module',
          'engine',
          'SearchEngine',
          isLazyAsync: true,
          parameters: [dep('Database')],
        ),
      ]);

      expect(source, isNot(contains('dependsOn')));
    });
  });

  group('a lazy module member', () {
    test('is registered lazily and awaits its call', () {
      final source = generate([
        provide('Module', 'engine', 'SearchEngine', isLazyAsync: true),
      ]);

      final flat = _flat(source);
      expect(flat, contains('registerLazyAsyncSingleton<_i137.SearchEngine>'));
      expect(flat, contains('await const _i137.Module().engine()'));
    });
  });

  group('what the build refuses', () {
    test('a synchronous class injecting a lazy one', () {
      expect(
        () => generate([
          declare('Model', isLazyAsync: true),
          declare('Screen', constructor: [dep('Model')]),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('Screen injects Model'),
              contains('@CobaltInit(lazy: true)'),
            ),
          ),
        ),
      );
    });

    test('an eager async class injecting a lazy one', () {
      expect(
        () => generate([
          declare('Model', isLazyAsync: true),
          declare('Warmup', isAsyncInit: true, constructor: [dep('Model')]),
        ]),
        throwsA(isA<CobaltGenerationError>()),
      );
    });

    test('an @injected field of a lazy type, even on a lazy class', () {
      expect(
        () => generate([
          declare('Model', isLazyAsync: true),
          declare(
            'SearchEngine',
            isLazyAsync: true,
            properties: [dep('Model', field: 'model')],
          ),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (error) => error.message,
            'message',
            contains('SearchEngine.model injects Model'),
          ),
        ),
      );
    });

    test('an async class waiting for a lazy one in dependsOn', () {
      expect(
        () => generate([
          declare('Model', isLazyAsync: true),
          declare('Warmup', isAsyncInit: true, dependsOn: [ref('Model')]),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (error) => error.message,
            'message',
            contains('cannot wait for a lazy async registration'),
          ),
        ),
      );
    });
  });

  test('a graph without lazy registrations is untouched', () {
    final source = generate([
      declare('Database', isAsyncInit: true),
      declare('Clock'),
    ]);

    expect(source, isNot(contains('getAsync')));
    expect(source, isNot(contains('registerLazyAsyncSingleton')));
  });
}
