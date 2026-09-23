import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('@CobaltScopeRoot emission', () {
    test('defaults to "root" when nothing is annotated', () {
      final source = generate([declare('Logger')]);

      expect(source, contains(r"const String $cobaltRootScopeName = 'root';"));
    });

    test('takes the name from the annotation', () {
      final source = generate(
        [declare('Logger')],
        scopeRoots: [scopeRoot('App', name: 'notes-app')],
      );

      expect(
        source,
        contains(r"const String $cobaltRootScopeName = 'notes-app';"),
      );
    });

    test('emits a start function wired to the generated container', () {
      final source = generate([declare('Logger')]);

      expect(source, contains(r'$startCobalt({'));
      expect(source, contains('overrides: overrides'));
      expect(source, contains(r'root: const $CobaltRootScope()'));
      expect(source, contains(r'rootName: $cobaltRootScopeName'));
    });

    test('passes the bootstrap list only when steps exist', () {
      final withSteps = generate(
        [declare('Logger')],
        bootstrap: [step('BindPlatform')],
      );
      final withoutSteps = generate([declare('Logger')]);

      expect(withSteps, contains(r'bootstrap: $cobaltBootstrap'));
      expect(withoutSteps, isNot(contains('bootstrap:')));
    });

    test('two roots in one package is a generation error', () {
      expect(
        () => generate(
          [declare('Logger')],
          scopeRoots: [
            scopeRoot('App'),
            scopeRoot('Other', name: 'other'),
          ],
        ),
        throwsA(
          isA<CobaltGenerationError>().having(
            (e) => e.message,
            'message',
            allOf(contains('App'), contains('Other'), contains('at most one')),
          ),
        ),
      );
    });

    test('no container means no start function', () {
      final source = generate(const [], bootstrap: [step('BindPlatform')]);

      expect(source, isNot(contains(r'$startCobalt')));
      expect(source, isNot(contains(r'$cobaltRootScopeName')));
    });
  });
}
