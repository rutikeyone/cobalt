import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('a graph without environments', () {
    test('keeps the const root scope and the plain start function', () {
      final source = generate(
        [declare('Logger')],
        scopeRoots: [scopeRoot('AppScope', name: 'app')],
      );

      expect(source, contains(r'const $CobaltRootScope();'));
      expect(
        source,
        matches(
          RegExp(
            r'\$startCobalt\(\{\s*List<_i\d+\.CobaltOverride<Object>> '
            r'overrides = const \[\],?\s*\}\) =>',
          ),
        ),
      );
      expect(source, isNot(contains('environment')));
    });
  });

  group('a graph with environments', () {
    String sourceOf() => generate([
      declare('Logger'),
      declare(
        'SqlNotes',
        exposeAs: ref('Notes'),
        environments: {'prod', 'stage'},
      ),
      declare('FakeNotes', exposeAs: ref('Notes'), environments: {'dev'}),
    ]);

    test('takes the chosen environment through the whole chain', () {
      final source = sourceOf();

      expect(
        source,
        matches(
          RegExp(
            r'const \$CobaltRootScope\(\{\s*this\.environment\s*=\s*'
            r'_i\d+\.CobaltEnvironment\.defaultEnvironment,?\s*\}\)',
          ),
        ),
      );
      expect(
        source,
        matches(RegExp(r'final _i\d+\.CobaltEnvironment environment;')),
      );
      expect(
        source,
        matches(
          RegExp(
            r'\$startCobalt\(\{\s*_i\d+\.CobaltEnvironment environment\s*=\s*'
            r'_i\d+\.CobaltEnvironment\.defaultEnvironment,\s*'
            r'List<_i\d+\.CobaltOverride<Object>> overrides = const \[\],?\s*\}\)',
          ),
        ),
        reason: 'environments are opt-in, so startup still works without one',
      );
      expect(
        source,
        contains(r'root: $CobaltRootScope(environment: environment),'),
      );
    });

    test('guards only the restricted registrations', () {
      final source = sourceOf();

      expect(source, contains("environment.matches(const <String>{'dev'})"));
      expect(
        source,
        contains("environment.matches(const <String>{'prod', 'stage'})"),
      );
      expect(
        registrationsOf(source).where((l) => l.contains('.Logger>')),
        hasLength(1),
        reason: 'an unrestricted registration stays unguarded',
      );
    });

    test('the same graph emits the same source twice', () {
      expect(sourceOf(), equals(sourceOf()));
    });
  });

  group('bootstrap steps', () {
    test('stay a getter while no step names an environment', () {
      final source = generate(
        [declare('Logger')],
        bootstrap: [step('BindPlatform')],
      );

      expect(source, contains(r'get $cobaltBootstrap'));
      expect(source, contains(r'bootstrap: $cobaltBootstrap,'));
    });

    test('become a function of the environment once one does', () {
      final source = generate(
        [declare('Logger')],
        bootstrap: [
          step('BindPlatform'),
          step('ReportCrashes', order: 1, environments: {'prod'}),
        ],
      );

      expect(source, isNot(contains(r'get $cobaltBootstrap')));
      expect(
        source,
        matches(
          RegExp(
            r'\$cobaltBootstrap\(\s*_i\d+\.CobaltEnvironment environment,?\s*\)',
          ),
        ),
      );
      expect(source, contains(r'bootstrap: $cobaltBootstrap(environment),'));
      expect(
        source,
        contains("if (environment.matches(const <String>{'prod'}))"),
      );
    });
  });

  group('conflicting registrations', () {
    test('two unrestricted registrations of one type are rejected', () {
      expect(
        () => generate([
          declare('SqlNotes', exposeAs: ref('Notes')),
          declare('FakeNotes', exposeAs: ref('Notes')),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (e) => e.message,
            'message',
            allOf(contains('SqlNotes'), contains('FakeNotes')),
          ),
        ),
      );
    });

    test('overlapping environments are rejected and name the overlap', () {
      expect(
        () => generate([
          declare(
            'SqlNotes',
            exposeAs: ref('Notes'),
            environments: {'prod', 'stage'},
          ),
          declare(
            'FakeNotes',
            exposeAs: ref('Notes'),
            environments: {'dev', 'stage'},
          ),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (e) => e.message,
            'message',
            contains('in stage'),
          ),
        ),
      );
    });

    test('an unrestricted registration conflicts with a restricted one', () {
      expect(
        () => generate([
          declare('SqlNotes', exposeAs: ref('Notes')),
          declare('FakeNotes', exposeAs: ref('Notes'), environments: {'dev'}),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (e) => e.message,
            'message',
            contains('names no environment'),
          ),
        ),
      );
    });

    test('disjoint environments are allowed', () {
      expect(
        () => generate([
          declare('SqlNotes', exposeAs: ref('Notes'), environments: {'prod'}),
          declare('FakeNotes', exposeAs: ref('Notes'), environments: {'dev'}),
        ]),
        returnsNormally,
      );
    });

    test('the same type under different names is not a conflict', () {
      expect(
        () => generate([
          declare('SqlNotes', exposeAs: ref('Notes'), name: 'sql'),
          declare('FakeNotes', exposeAs: ref('Notes'), name: 'fake'),
        ]),
        returnsNormally,
      );
    });
  });
}
