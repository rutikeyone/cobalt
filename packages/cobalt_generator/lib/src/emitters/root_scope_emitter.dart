import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/emitters/cobalt_factory_names.dart';
import 'package:cobalt_generator/src/emitters/cobalt_references.dart';
import 'package:code_builder/code_builder.dart';

class RootScopeEmitter {
  const RootScopeEmitter();

  /// [decorators] come in the order they are applied, the innermost first,
  /// and are added after every registration.
  Class emit(
    List<CobaltInjectableClass> ordered,
    CobaltFactoryNames names, {
    required bool usesEnvironments,
    List<CobaltDecoratorClass> decorators = const [],
  }) => Class(
    (b) => b
      ..name = r'$CobaltRootScope'
      ..modifier = ClassModifier.final$
      ..implements.add(cobaltRef('CobaltScopeBuilder'))
      ..constructors.add(
        Constructor(
          (c) => c
            ..constant = true
            ..optionalParameters.addAll([
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
              for (final declaration in ordered)
                guardedBy(
                  declaration.environments,
                  _register(declaration, names),
                ),
              for (final decorator in decorators)
                guardedBy(decorator.environments, _decorate(decorator, names)),
            ]),
        ),
      ),
  );

  Code _decorate(CobaltDecoratorClass decorator, CobaltFactoryNames names) {
    final name = decorator.name;
    return refer('scope').property('decorate').call(
      [refer(names.ofDecorator(decorator)).constInstance(const [])],
      {
        if (name != null) 'name': literalString(name),
        'debugLabel': literalString(decorator.type.name),
      },
      [typeReferenceOf(decorator.target)],
    ).statement;
  }

  Code _register(CobaltInjectableClass declaration, CobaltFactoryNames names) {
    final exposed = typeReferenceOf(declaration.exposedType);
    final factory = refer(names.of(declaration)).constInstance(const []);

    final dispose = declaration.dispose;
    final named = <String, Expression>{
      if (declaration.name != null) 'name': literalString(declaration.name!),
      if (declaration.isAsyncInit && declaration.dependsOn.isNotEmpty)
        'dependsOn': literalSet({
          for (final dependency in declaration.dependsOn)
            cobaltRef('CobaltKey').constInstance([typeReferenceOf(dependency)]),
        }),
      if (dispose != null) 'dispose': functionReferenceOf(dispose),
    };

    if (declaration.takesCallSiteValues) {
      return refer('scope')
          .property('registerParamFactory')
          .call([factory], named, [exposed, refer(names.argsOf(declaration))])
          .statement;
    }

    final method = declaration.isLazyAsync
        ? 'registerLazyAsyncSingleton'
        : declaration.isAsyncInit
        ? 'registerAsyncSingleton'
        : switch (declaration.lifetime) {
            CobaltLifetime.transient => 'registerFactory',
            CobaltLifetime.lazySingleton => 'registerLazySingleton',
            CobaltLifetime.singleton => 'registerEagerSingleton',
          };

    return refer(
      'scope',
    ).property(method).call([factory], named, [exposed]).statement;
  }
}
