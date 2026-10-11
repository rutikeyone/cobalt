import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/emitters/cobalt_factory_names.dart';
import 'package:cobalt_generator/src/emitters/cobalt_references.dart';
import 'package:cobalt_generator/src/emitters/root_scope_emitter.dart';
import 'package:code_builder/code_builder.dart';

class ChildScopeEmitter {
  const ChildScopeEmitter();

  static const _root = RootScopeEmitter();

  Class emit(
    CobaltChildScopeClass scope,
    List<CobaltInjectableClass> ordered,
    CobaltFactoryNames names,
  ) {
    final usesEnvironments = ordered.any(
      (declaration) => declaration.environments.isNotEmpty,
    );
    return Class(
      (b) => b
        ..name = scope.builderName
        ..modifier = ClassModifier.final$
        ..implements.add(cobaltRef('CobaltScopeBuilder'))
        ..constructors.add(
          Constructor(
            (c) => c
              ..constant = true
              ..requiredParameters.addAll([
                for (final value in scope.values)
                  if (!value.isNamed)
                    Parameter(
                      (p) => p
                        ..name = value.field
                        ..toThis = true,
                    ),
              ])
              ..optionalParameters.addAll([
                for (final value in scope.values)
                  if (value.isNamed)
                    Parameter(
                      (p) => p
                        ..name = value.field
                        ..named = true
                        ..required = true
                        ..toThis = true,
                    ),
                if (usesEnvironments)
                  Parameter(
                    (p) => p
                      ..name = 'environment'
                      ..named = true
                      ..toThis = true
                      ..defaultTo = defaultEnvironment.code,
                  ),
              ]),
          ),
        )
        ..fields.addAll([
          for (final value in scope.values)
            Field(
              (f) => f
                ..name = value.field
                ..modifier = FieldModifier.final$
                ..type = typeReferenceOf(value.type),
            ),
          if (usesEnvironments)
            Field(
              (f) => f
                ..name = 'environment'
                ..modifier = FieldModifier.final$
                ..type = cobaltRef('CobaltEnvironment'),
            ),
        ])
        ..methods.add(
          Method(
            (m) => m
              ..name = 'build'
              ..annotations.add(refer('override'))
              ..returns = refer('void')
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'scope'
                    ..type = cobaltRef('CobaltScope'),
                ),
              )
              ..body = Block.of([
                for (final entry in scope.provides) _root.promise(entry),
                for (final value in scope.values) _value(value),
                for (final declaration in ordered)
                  guardedBy(
                    declaration.environments,
                    _root.registration(declaration, names),
                  ),
              ]),
          ),
        ),
    );
  }

  Code _value(CobaltInjectedProperty value) {
    final name = value.name;
    return refer('scope').property('registerSingleton').call(
      [refer(value.field)],
      {if (name != null) 'name': literalString(name)},
      [typeReferenceOf(value.type)],
    ).statement;
  }
}
