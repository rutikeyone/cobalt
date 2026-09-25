import 'dart:convert';

import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

CobaltLibraryDeclarations roundTrip(CobaltLibraryDeclarations declarations) =>
    CobaltLibraryDeclarations.fromJson(
      jsonDecode(jsonEncode(declarations.toJson())) as Map<String, dynamic>,
    );

const appImport = 'package:app/app.dart';

CobaltTypeRef ref(String name) => CobaltTypeRef(name: name, import: appImport);

void main() {
  group('the IR survives the trip through .cobalt.json', () {
    test('a registration keeps its environments', () {
      final result = roundTrip(
        CobaltLibraryDeclarations(
          injectables: [
            CobaltInjectableClass(
              type: ref('SqlNotes'),
              exposeAs: ref('Notes'),
              lifetime: CobaltLifetime.lazySingleton,
              constructorParameters: const [],
              properties: const [],
              environments: const {'prod', 'stage'},
            ),
          ],
        ),
      );

      expect(result.injectables.single.environments, {'prod', 'stage'});
    });

    test('a bootstrap step keeps its environments', () {
      final result = roundTrip(
        CobaltLibraryDeclarations(
          bootstrapSteps: [
            CobaltBootstrapStepClass(
              type: ref('ReportCrashes'),
              order: 1,
              environments: const {'prod'},
            ),
          ],
        ),
      );

      expect(result.bootstrapSteps.single.environments, {'prod'});
    });

    test('naming no environment stays empty rather than becoming null', () {
      final result = roundTrip(
        CobaltLibraryDeclarations(
          injectables: [
            CobaltInjectableClass(
              type: ref('Logger'),
              lifetime: CobaltLifetime.lazySingleton,
              constructorParameters: const [],
              properties: const [],
            ),
          ],
        ),
      );

      expect(result.injectables.single.environments, isEmpty);
    });

    test('IR written before environments existed still reads', () {
      final legacy = {
        'injectables': [
          {
            'type': ref('Logger').toJson(),
            'lifetime': 'lazySingleton',
            'constructorParameters': <dynamic>[],
            'properties': <dynamic>[],
            'name': null,
            'exposeAs': null,
            'isAsyncInit': false,
            'dependsOn': <dynamic>[],
          },
        ],
      };

      final result = CobaltLibraryDeclarations.fromJson(legacy);

      expect(result.injectables.single.environments, isEmpty);
    });

    test('a scope root keeps what it promises is provided elsewhere', () {
      final result = roundTrip(
        CobaltLibraryDeclarations(
          scopeRoots: [
            CobaltScopeRootClass(
              type: ref('AppScope'),
              name: 'app',
              provides: [
                CobaltProvidedRef(type: ref('SessionManager')),
                CobaltProvidedRef(type: ref('Logger'), name: 'audit'),
              ],
            ),
          ],
        ),
      );

      final provides = result.scopeRoots.single.provides;
      expect(provides.map((p) => p.type.name), ['SessionManager', 'Logger']);
      expect(provides.map((p) => p.name), [null, 'audit']);
    });

    test('IR written before provides existed still reads', () {
      final legacy = {
        'scopeRoots': [
          {'type': ref('AppScope').toJson(), 'name': 'app'},
        ],
      };

      final result = CobaltLibraryDeclarations.fromJson(legacy);

      expect(result.scopeRoots.single.provides, isEmpty);
    });
  });

  /// The IR is the contract between the two build phases: the scan builder
  /// writes it, the container builder reads it. A flag lost here turns every
  /// parameterized class back into a plain registration, and until this test
  /// existed only a full build in another package noticed.
  test('a constructor parameter keeps its flags through JSON', () {
    final declaration = CobaltInjectableClass(
      type: const CobaltTypeRef(
        name: 'NoteEditor',
        import: 'package:app/a.dart',
      ),
      lifetime: CobaltLifetime.lazySingleton,
      constructorParameters: const [
        CobaltInjectedProperty(
          field: 'repo',
          type: CobaltTypeRef(name: 'Repo', import: 'package:app/a.dart'),
        ),
        CobaltInjectedProperty(
          field: 'id',
          type: CobaltTypeRef(name: 'int', import: 'dart:core'),
          isNamed: true,
          isParam: true,
        ),
        CobaltInjectedProperty(
          field: 'label',
          type: CobaltTypeRef(
            name: 'String',
            import: 'dart:core',
            isNullable: true,
          ),
          name: 'audit',
          isNamed: true,
          isParam: true,
        ),
      ],
      properties: const [],
    );

    final decoded = CobaltInjectableClass.fromJson(
      jsonDecode(jsonEncode(declaration.toJson())) as Map<String, dynamic>,
    );

    expect(
      decoded.constructorParameters.map((each) => (each.isNamed, each.isParam)),
      [(false, false), (true, true), (true, true)],
    );
    expect(decoded.callSiteValues.map((each) => each.field), ['id', 'label']);
    expect(decoded.constructorParameters.last.type.isNullable, isTrue);
    expect(decoded.constructorParameters.last.name, 'audit');
  });

  test('a parameter written by an older build reads as neither', () {
    final decoded = CobaltInjectedProperty.fromJson({
      'field': 'repo',
      'type': const CobaltTypeRef(
        name: 'Repo',
        import: 'package:app/a.dart',
      ).toJson(),
      'name': null,
    });

    expect(decoded.isNamed, isFalse);
    expect(decoded.isParam, isFalse);
  });

  test('a decorator keeps everything the container needs through JSON', () {
    final result = roundTrip(
      CobaltLibraryDeclarations(
        decorators: [
          CobaltDecoratorClass(
            type: ref('LoggingApi'),
            target: ref('Api'),
            inner: 'inner',
            name: 'primary',
            order: 2,
            environments: const {'dev'},
            constructorParameters: [
              CobaltInjectedProperty(
                field: 'log',
                type: ref('Logger'),
                name: 'audit',
              ),
              CobaltInjectedProperty(
                field: 'inner',
                type: ref('Api'),
                isNamed: true,
              ),
            ],
          ),
        ],
      ),
    );

    final decorator = result.decorators.single;
    expect(decorator.type.name, 'LoggingApi');
    expect(decorator.target.name, 'Api');
    expect(decorator.inner, 'inner');
    expect(decorator.name, 'primary');
    expect(decorator.order, 2);
    expect(decorator.environments, {'dev'});
    expect(decorator.dependencies.single.name, 'audit');
    expect(decorator.constructorParameters.last.isNamed, isTrue);
    expect(result.isEmpty, isFalse);
  });

  test('IR written before decorators existed still reads', () {
    final result = CobaltLibraryDeclarations.fromJson(const {
      'injectables': <Object>[],
    });

    expect(result.decorators, isEmpty);
    expect(result.toJson(), isNot(contains('decorators')));
  });
}
