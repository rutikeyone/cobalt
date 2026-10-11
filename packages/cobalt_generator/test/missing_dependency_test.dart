import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher failsWith(Object matcher) => throwsA(
  isA<CobaltGenerationError>().having((e) => e.message, 'message', matcher),
);

void main() {
  group('missing registrations', () {
    test('a dependency nothing registers fails the build', () {
      expect(
        () => generate([
          declare('Api', constructor: [dep('HttpClient')]),
        ]),
        failsWith(
          allOf(
            contains('Api requires HttpClient'),
            contains('nothing registers'),
          ),
        ),
      );
    });

    test('an injected property counts too', () {
      expect(
        () => generate([
          declare('Bloc', properties: [dep('Logger')]),
        ]),
        failsWith(contains('Bloc requires Logger')),
      );
    });

    test('every missing registration is reported at once', () {
      expect(
        () => generate([
          declare('Api', constructor: [dep('HttpClient')]),
          declare('Bloc', properties: [dep('Logger')]),
        ]),
        failsWith(
          allOf(
            contains('missing 2 registrations'),
            contains('Api requires HttpClient'),
            contains('Bloc requires Logger'),
          ),
        ),
      );
    });

    test('a name that nothing registers under is missing', () {
      expect(
        () => generate([
          declare('Logger'),
          declare('Api', constructor: [dep('Logger', name: 'audit')]),
        ]),
        failsWith(contains("Api requires Logger named 'audit'")),
      );
    });

    test('dependsOn on an unregistered type is missing', () {
      expect(
        () => generate([
          declare('Index', isAsyncInit: true, dependsOn: [ref('Database')]),
        ]),
        failsWith(contains('Index requires Database')),
      );
    });

    test('a dependency on the concrete class behind exposeAs is missing', () {
      expect(
        () => generate([
          declare('SqlNotes', exposeAs: ref('Notes')),
          declare('Editor', constructor: [dep('SqlNotes')]),
        ]),
        failsWith(contains('Editor requires SqlNotes')),
      );
    });

    test('an optional dependency is not reported missing', () {
      final source = generate([
        declare('Api', constructor: [dep('HttpClient', isNullable: true)]),
      ]);

      expect(registrationsOf(source), hasLength(1));
      expect(source, contains('resolver.getOrNull<'));
    });

    test('a nullable dependsOn is still required, being an ordering edge', () {
      expect(
        () => generate([
          declare(
            'Index',
            isAsyncInit: true,
            dependsOn: [ref('Database', isNullable: true)],
          ),
        ]),
        failsWith(contains('Index requires Database')),
      );
    });

    test('an optional dependency still orders registration when present', () {
      final source = generate([
        declare('Api', constructor: [dep('HttpClient', isNullable: true)]),
        declare('HttpClient'),
      ]);

      final order = registrationsOf(source);
      expect(
        order.first,
        contains('HttpClient'),
        reason: 'optional does not mean unordered — it is still an edge',
      );
      expect(order.last, contains('Api'));
    });
  });

  group('provides', () {
    test('a listed type satisfies the dependency', () {
      final source = generate(
        [
          declare('Api', constructor: [dep('HttpClient')]),
        ],
        scopeRoots: [
          scopeRoot('AppScope', provides: [provided('HttpClient')]),
        ],
      );

      expect(registrationsOf(source), hasLength(1));
    });

    test('a name has to match to satisfy a named dependency', () {
      expect(
        () => generate(
          [
            declare('Api', constructor: [dep('Logger', name: 'audit')]),
          ],
          scopeRoots: [
            scopeRoot('AppScope', provides: [provided('Logger')]),
          ],
        ),
        failsWith(contains("Api requires Logger named 'audit'")),
      );
    });

    test('a named entry satisfies a named dependency', () {
      final source = generate(
        [
          declare('Api', constructor: [dep('Logger', name: 'audit')]),
        ],
        scopeRoots: [
          scopeRoot('AppScope', provides: [provided('Logger', name: 'audit')]),
        ],
      );

      expect(registrationsOf(source), hasLength(1));
    });

    test('a provided dependency is not registered, only promised', () {
      final source = generate(
        [
          declare('Api', constructor: [dep('HttpClient')]),
        ],
        scopeRoots: [
          scopeRoot('AppScope', provides: [provided('HttpClient')]),
        ],
      );

      expect(source, isNot(contains('HttpClientFactory')));
    });

    test('each listed type is promised to the root, by name if it has one', () {
      final source = generate(
        [
          declare(
            'Api',
            constructor: [
              dep('HttpClient'),
              dep('Logger', name: 'audit'),
            ],
          ),
        ],
        scopeRoots: [
          scopeRoot(
            'AppScope',
            provides: [
              provided('HttpClient'),
              provided('Logger', name: 'audit'),
            ],
          ),
        ],
      );

      final promises = source
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.startsWith('scope.promise'))
          .toList();
      expect(promises, [
        matches(r'^scope\.promise<_i\d+\.HttpClient>\(\);$'),
        matches(r"^scope\.promise<_i\d+\.Logger>\(name: 'audit'\);$"),
      ]);
    });

    test('nothing listed, nothing promised', () {
      final source = generate([declare('Api')]);

      expect(source, isNot(contains('scope.promise')));
    });
  });

  group('environments', () {
    test('a restricted dependency satisfies a dependent in the same one', () {
      final source = generate([
        declare('LiveApi', exposeAs: ref('Api'), environments: {'prod'}),
        declare('FakeApi', exposeAs: ref('Api'), environments: {'dev'}),
        declare('Gateway', constructor: [dep('Api')]),
      ]);

      expect(registrationsOf(source), hasLength(3));
    });

    test('a dependent outlives its dependency in the other environment', () {
      expect(
        () => generate([
          declare('FakeApi', exposeAs: ref('Api'), environments: {'dev'}),
          declare('Live', environments: {'prod'}),
          declare('Gateway', constructor: [dep('Api')]),
        ]),
        failsWith(allOf(contains('Gateway requires Api'), contains('in prod'))),
      );
    });

    test('a gap in every environment does not name one', () {
      expect(
        () => generate([
          declare('FakeApi', environments: {'dev'}),
          declare('LiveApi', environments: {'prod'}),
          declare('Gateway', constructor: [dep('HttpClient')]),
        ]),
        failsWith(
          allOf(
            contains('Gateway requires HttpClient,'),
            isNot(contains('in dev')),
          ),
        ),
      );
    });

    test('the default environment is not checked once a graph splits', () {
      final source = generate([
        declare('FakeApi', exposeAs: ref('Api'), environments: {'dev'}),
        declare('LiveApi', exposeAs: ref('Api'), environments: {'prod'}),
        declare('Gateway', constructor: [dep('Api')]),
      ]);

      expect(registrationsOf(source), hasLength(3));
    });

    test('a graph without environments is still checked', () {
      expect(
        () => generate([
          declare('Gateway', constructor: [dep('Api')]),
        ]),
        failsWith(contains('Gateway requires Api')),
      );
    });
  });
}
