import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/emitters/cobalt_factory_names.dart';
import 'package:cobalt_generator/src/emitters/cobalt_references.dart';
import 'package:code_builder/code_builder.dart';

/// Emits the `CobaltDecorator` an `@CobaltDecorates` class stands for.
///
/// A const class with no state, like a factory: the wrapped instance and the
/// resolver arrive as arguments, and the class is rebuilt around them. A class
/// with `@injected` fields has them filled by its generated mixin right after
/// construction, from the same resolver — the scope never calls `onInject`
/// on what a decorator returns, since that may be the instance it was handed.
class DecoratorEmitter {
  const DecoratorEmitter();

  Class emit(CobaltDecoratorClass decorator, CobaltFactoryNames names) {
    final target = typeReferenceOf(decorator.target);

    Expression argument(CobaltInjectedProperty parameter) =>
        parameter.field == decorator.inner
        ? refer('inner')
        : resolveCall(parameter);

    final construction = typeReferenceOf(decorator.type).newInstance(
      [
        for (final parameter in decorator.constructorParameters)
          if (!parameter.isNamed) argument(parameter),
      ],
      {
        for (final parameter in decorator.constructorParameters)
          if (parameter.isNamed) parameter.field: argument(parameter),
      },
    );

    return Class(
      (b) => b
        ..name = names.ofDecorator(decorator)
        ..modifier = ClassModifier.final$
        ..implements.add(cobaltGeneric('CobaltDecorator', target))
        ..constructors.add(Constructor((c) => c..constant = true))
        ..methods.add(
          Method(
            (m) => m
              ..name = 'decorate'
              ..annotations.add(refer('override'))
              ..returns = target
              ..requiredParameters.addAll([
                Parameter(
                  (p) => p
                    ..name = 'inner'
                    ..type = target,
                ),
                Parameter(
                  (p) => p
                    ..name = 'resolver'
                    ..type = cobaltRef('CobaltResolver'),
                ),
              ])
              ..lambda = true
              ..body =
                  (decorator.hasPropertyInjection
                          ? construction.cascade('onInject').call([
                              refer('resolver'),
                            ])
                          : construction)
                      .code,
          ),
        ),
    );
  }
}
