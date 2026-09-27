import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher failsWith(Object message) => throwsA(
  isA<CobaltGenerationError>().having((e) => e.message, 'message', message),
);

void main() {
  group('an async class built from a call-site value', () {
    final source = generate([
      declare('Repo'),
      declare(
        'Document',
        isAsyncInit: true,
        constructor: [dep('Repo'), arg('id', 'int')],
      ),
    ]);

    test('is an async parameterized factory that awaits init', () {
      expect(
        source,
        matches(
          RegExp(
            r'implements\s+_i\d+\.CobaltAsyncParamFactory<_i\d+\.Document, '
            r'\$DocumentArgs>',
          ),
        ),
      );
      expect(
        source,
        matches(
          RegExp(
            r'Future<_i\d+\.Document> create\(\s*_i\d+\.CobaltResolver '
            r'resolver,\s*\$DocumentArgs args,?\s*\) async \{\s*'
            r'final instance = _i\d+\.Document\(\s*resolver\.get<_i\d+\.Repo>\(\),'
            r'\s*id: args\.id,?\s*\);\s*await instance\.init\(\);\s*'
            r'return instance;',
          ),
        ),
      );
    });

    test('is registered with registerAsyncParamFactory', () {
      expect(
        source,
        matches(
          RegExp(
            r'scope\.registerAsyncParamFactory<_i\d+\.Document, \$DocumentArgs>'
            r'\(\s*const _DocumentFactory\(\),?\s*\);',
          ),
        ),
      );
      expect(source, contains(r'typedef $DocumentArgs = ({int id});'));
    });

    test('awaits a lazy dependency instead of reading it', () {
      final lazy = generate([
        declare('Engine', isLazyAsync: true),
        declare(
          'Document',
          isAsyncInit: true,
          constructor: [dep('Engine'), arg('id', 'int')],
        ),
      ]);

      expect(lazy, matches(RegExp(r'await resolver\.getAsync<_i\d+\.Engine>')));
    });

    test('is not waited for in phase 1 by the classes it depends on', () {
      final chained = generate([
        declare('Database', isAsyncInit: true),
        declare(
          'Document',
          isAsyncInit: true,
          constructor: [dep('Database'), arg('id', 'int')],
        ),
      ]);

      expect(chained, isNot(contains('dependsOn')));
    });

    test('takes no dependsOn from the decorators it reaches', () {
      final decorated = generate(
        [
          declare('Database', isAsyncInit: true),
          declare('Clock', isAsyncInit: true),
          declare(
            'Document',
            isAsyncInit: true,
            constructor: [dep('Database'), arg('id', 'int')],
          ),
        ],
        decorators: [
          decorator('TimedDatabase', 'Database', dependencies: [dep('Clock')]),
        ],
      );

      expect(decorated, isNot(contains('dependsOn')));
    });
  });

  group('what the build refuses', () {
    test('dependsOn naming it', () {
      expect(
        () => generate([
          declare(
            'Document',
            isAsyncInit: true,
            constructor: [arg('id', 'int')],
          ),
          declare('Search', isAsyncInit: true, dependsOn: [ref('Document')]),
        ]),
        failsWith(
          allOf(
            contains('built from a call-site value'),
            contains('Search waits for Document'),
          ),
        ),
      );
    });
  });
}
