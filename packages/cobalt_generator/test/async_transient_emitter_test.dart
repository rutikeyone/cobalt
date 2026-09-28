import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher failsWith(Object message) => throwsA(
  isA<CobaltGenerationError>().having((e) => e.message, 'message', message),
);

CobaltInjectableClass asyncTransient(
  String type, {
  List<CobaltInjectedProperty> constructor = const [],
}) => declare(
  type,
  lifetime: CobaltLifetime.transient,
  isAsyncInit: true,
  constructor: constructor,
);

void main() {
  group('a transient async class', () {
    final source = generate([
      declare('Repo'),
      asyncTransient('Report', constructor: [dep('Repo')]),
    ]);

    test('is an async factory that awaits init', () {
      expect(
        source,
        matches(
          RegExp(r'implements\s+_i\d+\.CobaltAsyncFactory<_i\d+\.Report>'),
        ),
      );
      expect(
        source,
        matches(
          RegExp(
            r'final instance = _i\d+\.Report\(\s*resolver\.get<_i\d+\.Repo>\(\),?'
            r'\s*\);\s*await instance\.init\(\);\s*return instance;',
          ),
        ),
      );
    });

    test('is registered with registerAsyncFactory', () {
      expect(
        source,
        matches(
          RegExp(
            r'scope\.registerAsyncFactory<_i\d+\.Report>\(\s*'
            r'const _ReportFactory\(\),?\s*\);',
          ),
        ),
      );
      expect(source, isNot(contains('registerAsyncSingleton')));
    });

    test('awaits a lazy dependency instead of reading it', () {
      final lazy = generate([
        declare('Engine', isLazyAsync: true),
        asyncTransient('Report', constructor: [dep('Engine')]),
      ]);

      expect(lazy, matches(RegExp(r'await resolver\.getAsync<_i\d+\.Engine>')));
    });

    test('may be taken by a lazy class, which awaits it', () {
      final chained = generate([
        asyncTransient('Connection'),
        declare('Search', isLazyAsync: true, constructor: [dep('Connection')]),
      ]);

      expect(
        chained,
        matches(RegExp(r'await resolver\.getAsync<_i\d+\.Connection>')),
      );
    });

    test('is not waited for in phase 1 by the classes it depends on', () {
      final chained = generate([
        declare('Database', isAsyncInit: true),
        asyncTransient('Report', constructor: [dep('Database')]),
      ]);

      expect(chained, isNot(contains('dependsOn')));
    });

    test('a module member returning a Future awaits the call', () {
      final member = generate([
        provide(
          'Module',
          'connection',
          'Connection',
          lifetime: CobaltLifetime.transient,
          isAsyncInit: true,
        ),
      ]);

      expect(
        member,
        matches(RegExp(r'scope\.registerAsyncFactory<_i\d+\.Connection>')),
      );
    });
  });

  group('what the build refuses', () {
    test('a synchronous class taking it', () {
      expect(
        () => generate([
          asyncTransient('Report'),
          declare('Screen', constructor: [dep('Report')]),
        ]),
        failsWith(
          allOf(
            contains('an async transient can only be injected'),
            contains('Screen injects Report'),
          ),
        ),
      );
    });

    test('an eager async class taking it', () {
      expect(
        () => generate([
          asyncTransient('Report'),
          declare('Archive', isAsyncInit: true, constructor: [dep('Report')]),
        ]),
        failsWith(contains('Archive injects Report')),
      );
    });

    test('an @injected field of its type', () {
      expect(
        () => generate([
          asyncTransient('Report'),
          declare('Screen', properties: [dep('Report')]),
        ]),
        failsWith(contains('Screen.report injects Report')),
      );
    });

    test('dependsOn naming it', () {
      expect(
        () => generate([
          asyncTransient('Report'),
          declare('Search', isAsyncInit: true, dependsOn: [ref('Report')]),
        ]),
        failsWith(
          allOf(
            contains('cannot wait for an async transient'),
            contains('Search waits for Report'),
          ),
        ),
      );
    });

    test('a decorator taking it', () {
      expect(
        () => generate(
          [declare('Api'), asyncTransient('Report')],
          decorators: [
            decorator('LoggedApi', 'Api', dependencies: [dep('Report')]),
          ],
        ),
        failsWith(contains('A decorator cannot take a lazy async')),
      );
    });
  });
}
