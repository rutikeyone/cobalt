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
    CobaltFactoryNames names, {
    List<CobaltDecoratorClass> decorators = const [],
  }) {
    final usesEnvironments =
        ordered.any((declaration) => declaration.environments.isNotEmpty) ||
        decorators.any((decorator) => decorator.environments.isNotEmpty);
    return Class(
      (b) => b
        ..name = scope.builderName
        ..modifier = ClassModifier.final$
        ..extend = cobaltRef('CobaltChildScopeBuilder')
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
                      ..toThis = true,
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
                ..type = TypeReference(
                  (t) => t
                    ..symbol = 'CobaltEnvironment'
                    ..url = cobaltUrl
                    ..isNullable = true,
                ),
            ),
        ])
        ..methods.addAll([
          Method(
            (m) => m
              ..name = 'marker'
              ..type = MethodType.getter
              ..annotations.add(refer('override'))
              ..returns = refer('Type')
              ..lambda = true
              ..body = typeReferenceOf(scope.type).code,
          ),
          if (scope.parent case final parent?)
            Method(
              (m) => m
                ..name = 'parent'
                ..type = MethodType.getter
                ..annotations.add(refer('override'))
                ..returns = TypeReference(
                  (r) => r
                    ..symbol = 'Type'
                    ..isNullable = true,
                )
                ..lambda = true
                ..body = typeReferenceOf(parent).code,
            ),
          _markerValues(scope, usesEnvironments: usesEnvironments),
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
                if (usesEnvironments) ...[
                  declareFinal('environment')
                      .assign(
                        refer('this')
                            .property('environment')
                            .ifNullThen(refer('scope').property('environment'))
                            .ifNullThen(defaultEnvironment),
                      )
                      .statement,
                  refer('scope').property('useEnvironment').call([
                    refer('environment'),
                  ]).statement,
                ],
                for (final entry in scope.provides) _root.promise(entry),
                for (final value in scope.values) _value(value),
                for (final declaration in ordered)
                  guardedBy(
                    declaration.environments,
                    _root.registration(declaration, names),
                  ),
                for (final decorator in decorators)
                  guardedBy(
                    decorator.environments,
                    _root.decoration(decorator, names),
                  ),
              ]),
          ),
        ),
    );
  }

  Method _markerValues(
    CobaltChildScopeClass scope, {
    required bool usesEnvironments,
  }) {
    final fields = [
      for (final value in scope.values) refer(value.field),
      if (usesEnvironments) refer('environment'),
    ];
    final type = TypeReference(
      (t) => t
        ..symbol = 'Object'
        ..isNullable = true,
    );
    return Method(
      (m) => m
        ..name = 'markerValues'
        ..type = MethodType.getter
        ..annotations.add(refer('override'))
        ..returns = TypeReference(
          (t) => t
            ..symbol = 'List'
            ..types.add(type),
        )
        ..lambda = true
        ..body = fields.isEmpty
            ? literalConstList(const [], type).code
            : literalList(fields).code,
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
