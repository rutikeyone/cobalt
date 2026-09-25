import 'package:cobalt_analyzer/src/model/decorator_class.dart';
import 'package:cobalt_analyzer/src/model/injected_property.dart';
import 'package:cobalt_analyzer/src/parser/cobalt_matchers.dart';
import 'package:cobalt_analyzer/src/parser/dart_object_reader.dart';
import 'package:cobalt_analyzer/src/parser/environment_reader.dart';
import 'package:cobalt_analyzer/src/parser/parse_error.dart';
import 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
import 'package:analyzer/dart/element/element.dart';

/// Reads an `@CobaltDecorates` class into the wrapper the container applies.
class CobaltDecoratorParser {
  const CobaltDecoratorParser();

  bool declares(ClassElement clazz) => decoratesMatcher.matches(clazz);

  CobaltDecoratorClass parseClass(ClassElement clazz) {
    final annotations = decoratesMatcher.allOf(clazz);
    if (annotations.length > 1) {
      throw CobaltParseError(
        '${clazz.displayName} carries @CobaltDecorates more than once. One '
        'class wraps one registration; write a class per target.',
        clazz,
      );
    }
    final annotation = annotations.single;

    if (injectMatcher.matches(clazz) ||
        initMatcher.matches(clazz) ||
        moduleMatcher.matches(clazz)) {
      throw CobaltParseError(
        '${clazz.displayName} is both a decorator and a registration. A '
        'decorator claims no key of its own — it is built around the instance '
        'it wraps. Drop @CobaltInject, @CobaltInit or @CobaltModule.',
        clazz,
      );
    }
    if (clazz.isAbstract) {
      throw CobaltParseError(
        '${clazz.displayName} is abstract and cannot be constructed.',
        clazz,
      );
    }
    if (clazz.typeParameters.isNotEmpty) {
      throw CobaltParseError(
        '${clazz.displayName} declares type parameters, so there is no single '
        'instantiation to build around the registration.',
        clazz,
      );
    }

    final target = annotation.getField('target')?.toTypeValue();
    if (target == null) {
      throw CobaltParseError(
        '${clazz.displayName} does not say which type it decorates.',
        clazz,
      );
    }
    final targetRef = typeRefOf(target);

    if (!clazz.library.typeSystem.isSubtypeOf(clazz.thisType, target)) {
      throw CobaltParseError(
        '${clazz.displayName} decorates ${targetRef.name} but is not one. '
        'Callers of get<${targetRef.name}>() receive the decorator, so it has '
        'to implement ${targetRef.name}.',
        clazz,
      );
    }

    final constructor = clazz.constructors
        .where((c) => c.isPublic && !c.isFactory)
        .firstOrNull;
    if (constructor == null) {
      throw CobaltParseError(
        '${clazz.displayName} has no public generative constructor.',
        clazz,
      );
    }

    final parameters = constructor.formalParameters;
    final inner = [
      for (final parameter in parameters)
        if (typeRefOf(parameter.type).signature == targetRef.signature)
          parameter,
    ];
    if (inner.length != 1) {
      throw CobaltParseError(
        '${clazz.displayName} decorates ${targetRef.name}, so its constructor '
        'takes exactly one ${targetRef.name} — the instance it wraps. It takes '
        '${inner.length}.',
        clazz,
      );
    }

    if (parameters.any(paramMatcher.matches)) {
      throw CobaltParseError(
        '${clazz.displayName} marks a parameter with @CobaltParam. A decorator '
        'is applied by the scope, which has no call site to take a value '
        'from.',
        clazz,
      );
    }
    for (final field in clazz.fields) {
      if (!injectedMatcher.matches(field)) continue;
      throw CobaltParseError(
        '${clazz.displayName}.${field.displayName} is @injected. A decorator '
        'takes its dependencies through the constructor.',
        field,
      );
    }

    return CobaltDecoratorClass(
      type: typeRefOfElement(clazz),
      target: targetRef,
      inner: inner.single.name ?? '',
      name: annotation.readString('name'),
      order: annotation.readInt('order'),
      environments: environmentsOf(clazz),
      constructorParameters: [
        for (final parameter in parameters)
          CobaltInjectedProperty(
            field: parameter.name ?? '',
            type: typeRefOf(parameter.type),
            name: namedMatcher.firstOf(parameter)?.readString('name'),
            isNamed: parameter.isNamed,
          ),
      ],
    );
  }
}
