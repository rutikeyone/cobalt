import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/emitters/cobalt_references.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:code_builder/code_builder.dart';

class StartFunctionEmitter {
  const StartFunctionEmitter();

  static const defaultScopeName = 'root';

  String resolveName(List<CobaltScopeRootClass> roots) {
    if (roots.isEmpty) return defaultScopeName;
    if (roots.length > 1) {
      final names = ([
        for (final root in roots) root.type.name,
      ]..sort()).join(', ');
      throw CobaltGenerationError(
        'Found ${roots.length} classes annotated with @CobaltScopeRoot: $names. '
        'A package can declare at most one root scope.',
      );
    }
    return roots.single.name;
  }

  Field emitName(String name) => Field(
    (f) => f
      ..name = r'$cobaltRootScopeName'
      ..modifier = FieldModifier.constant
      ..type = refer('String', 'dart:core')
      ..assignment = literalString(name).code,
  );

  Method emitStart({
    required bool hasBootstrap,
    required bool scopeUsesEnvironments,
    required bool bootstrapUsesEnvironments,
  }) {
    final usesEnvironments = scopeUsesEnvironments || bootstrapUsesEnvironments;
    final environment = refer('environment');

    return Method(
      (m) => m
        ..name = r'$startCobalt'
        ..optionalParameters.addAll([
          if (usesEnvironments)
            Parameter(
              (p) => p
                ..name = 'environment'
                ..named = true
                ..type = cobaltRef('CobaltEnvironment')
                ..defaultTo = defaultEnvironment.code,
            ),
          Parameter(
            (p) => p
              ..name = 'overrides'
              ..named = true
              ..type = TypeReference(
                (b) => b
                  ..symbol = 'List'
                  ..url = 'dart:core'
                  ..types.add(
                    TypeReference(
                      (o) => o
                        ..symbol = 'CobaltOverride'
                        ..url = cobaltUrl
                        ..types.add(refer('Object', 'dart:core')),
                    ),
                  ),
              )
              ..defaultTo = literalConstList(const []).code,
          ),
        ])
        ..returns = TypeReference(
          (b) => b
            ..symbol = 'Future'
            ..url = 'dart:async'
            ..types.add(cobaltRef('CobaltScope')),
        )
        ..lambda = true
        ..body = cobaltRef('CobaltApplication').property('start').call(
          const [],
          {
            'root': scopeUsesEnvironments
                ? refer(
                    r'$CobaltRootScope',
                  ).newInstance(const [], {'environment': environment})
                : refer(r'$CobaltRootScope').constInstance(const []),
            if (hasBootstrap)
              'bootstrap': bootstrapUsesEnvironments
                  ? refer(r'$cobaltBootstrap').call([environment])
                  : refer(r'$cobaltBootstrap'),
            'rootName': refer(r'$cobaltRootScopeName'),
            'overrides': refer('overrides'),
          },
        ).code,
    );
  }
}
