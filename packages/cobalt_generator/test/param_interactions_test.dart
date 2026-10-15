import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

CobaltInjectableClass declaredIn(
  String library,
  String name, {
  List<CobaltInjectedProperty> constructor = const [],
}) => CobaltInjectableClass(
  type: CobaltTypeRef(name: name, import: library),
  lifetime: CobaltLifetime.lazySingleton,
  constructorParameters: constructor,
  properties: const [],
);

void main() {
  group('a parameterized registration combined with', () {
    test('exposeAs registers the interface and builds the class', () {
      final source = generate([
        declare(
          'FileEditor',
          exposeAs: ref('Editor'),
          constructor: [arg('id', 'int')],
        ),
      ]);

      expect(source, contains('typedef FileEditorArgs = ({int id});'));
      expect(
        source,
        contains('CobaltParamFactory<_i137.Editor, FileEditorArgs>'),
        reason: 'the factory produces what is registered, not what is built',
      );
      expect(
        source,
        contains('registerParamFactory<_i137.Editor, FileEditorArgs>'),
      );
    });

    test('a name keeps it on the registration', () {
      final source = generate([
        declare('Editor', name: 'wide', constructor: [arg('id', 'int')]),
      ]);

      expect(source, contains("name: 'wide'"));
    });

    test('an environment guards the registration', () {
      final source = generate([
        declare(
          'Editor',
          environments: {'dev'},
          constructor: [arg('id', 'int')],
        ),
      ]);

      expect(source, contains("environment.matches(const <String>{'dev'})"));
      expect(source, contains('registerParamFactory'));
    });

    test('property injection still fills the fields', () {
      final source = generate([
        declare('Logger'),
        declare(
          'Editor',
          constructor: [arg('id', 'int')],
          properties: [dep('Logger')],
        ),
      ]);

      expect(source, contains('registerParamFactory'));
      expect(
        source,
        contains('_i137.Logger'),
        reason: 'an injected field is still a dependency of the class',
      );
    });

    test('a nullable value keeps its nullability in the record', () {
      final source = generate([
        declare(
          'Editor',
          constructor: [
            CobaltInjectedProperty(
              field: 'title',
              type: CobaltTypeRef(
                name: 'String',
                import: 'dart:core',
                isNullable: true,
              ),
              isNamed: true,
              isParam: true,
            ),
          ],
        ),
      ]);

      expect(source, contains('typedef EditorArgs = ({String? title});'));
    });
  });

  /// The same collision the factory name has, in the type beside it.
  test('two same-named classes get two argument types', () {
    final source = generate([
      declaredIn(
        'package:app/a/editor.dart',
        'Editor',
        constructor: [arg('id', 'int')],
      ),
      declaredIn(
        'package:app/b/editor.dart',
        'Editor',
        constructor: [arg('id', 'int')],
      ),
    ]);

    final names = RegExp(
      r'typedef (\$Editor\S*) =',
    ).allMatches(source).map((match) => match.group(1)).toSet();

    expect(names, hasLength(2), reason: 'two declarations, two record types');
    expect(
      source,
      isNot(contains(r'typedef $EditorArgs =')),
      reason: 'suffixing only one would make the name depend on visit order',
    );
  });
}
