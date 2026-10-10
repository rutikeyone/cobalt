import 'package:cobalt_analyzer/src/model/injectable_class.dart';
import 'package:cobalt_analyzer/src/model/injected_property.dart';
import 'package:cobalt_analyzer/src/model/type_ref.dart';
import 'package:cobalt_analyzer/src/parser/cobalt_matchers.dart';
import 'package:cobalt_analyzer/src/parser/dart_object_reader.dart';
import 'package:cobalt_analyzer/src/parser/dispose_reader.dart';
import 'package:cobalt_analyzer/src/parser/environment_reader.dart';
import 'package:cobalt_analyzer/src/parser/injected_field_reader.dart';
import 'package:cobalt_analyzer/src/parser/parse_error.dart';
import 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
import 'package:cobalt_annotations/cobalt_annotations.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

class CobaltInjectableParser {
  const CobaltInjectableParser();

  bool declares(ClassElement clazz) =>
      injectMatcher.matches(clazz) || initMatcher.matches(clazz);

  /// One registration per instantiation [clazz] names, or a single one when
  /// it declares no type parameters.
  List<CobaltInjectableClass> parseClass(ClassElement clazz) {
    final initAnnotation = initMatcher.firstOf(clazz);
    final isAsyncInit = initAnnotation != null;
    final injectAnnotation = injectMatcher.firstOf(clazz);
    final annotation = injectAnnotation ?? initAnnotation!;

    final instantiations = _instantiationsOf(clazz, injectAnnotation);

    final constructor = _constructorOf(clazz);
    final takesParams = constructor.formalParameters.any(paramMatcher.matches);

    for (final parameter in constructor.formalParameters) {
      if (!paramMatcher.matches(parameter) || !parameter.isOptional) continue;
      throw CobaltParseError(
        '${clazz.displayName} marks ${parameter.displayName} with @CobaltParam '
        'and leaves it optional. The record the call site passes has no '
        'defaults, so the default would never be used. Make it required, or '
        'make its type nullable and pass null.',
        clazz,
      );
    }

    if (takesParams &&
        _lifetimeOf(annotation, isAsyncInit: false) ==
            CobaltLifetime.singleton) {
      throw CobaltParseError(
        '${clazz.displayName} asks for a singleton and takes an @CobaltParam. '
        'A singleton is built while the container is assembled, when no call '
        'site has supplied anything yet. Drop the lifetime — a parameterized '
        'registration is never retained by the scope.',
        clazz,
      );
    }

    final lifetime = _lifetimeOf(annotation, isAsyncInit: isAsyncInit);
    final dispose = disposeOf(annotation, clazz.displayName, clazz);

    if (dispose != null &&
        (takesParams || lifetime == CobaltLifetime.transient)) {
      throw CobaltParseError(
        '${clazz.displayName} names a dispose function, but the scope never '
        'retains ${takesParams ? 'a parameterized registration' : 'a transient'} '
        'and so could never call it. Give it a lifetime the scope keeps, or '
        'let the caller close what it built.',
        clazz,
      );
    }

    if (isAsyncInit && !_hasInitMethod(clazz)) {
      throw CobaltParseError(
        '${clazz.displayName} is annotated with @CobaltInit but declares no '
        "'Future<void> init()' method. Implement AsyncInitializable.",
        clazz,
      );
    }

    if (injectAnnotation?.readBool('lazyInit') ?? false) {
      throw CobaltParseError(
        '${clazz.displayName} is @CobaltInject(lazyInit: true). lazyInit is '
        'the module-member form; on a class, say @CobaltInit(lazy: true) — the '
        'class needs an init() to be async at all.',
        clazz,
      );
    }

    final isLazyAsync = initAnnotation?.readBool('lazy') ?? false;
    final dependsOn = _dependsOnOf(initAnnotation);

    if (takesParams && isLazyAsync) {
      throw CobaltParseError(
        '${clazz.displayName} is @CobaltInit(lazy: true) and takes an '
        '@CobaltParam. A lazy registration is one instance built by the first '
        'getAsync; a call-site value builds a new one on every call. Drop lazy '
        '— @CobaltInit with an @CobaltParam is already built only when asked, '
        'through getAsyncWithParam.',
        clazz,
      );
    }
    if (takesParams && dependsOn.isNotEmpty) {
      throw CobaltParseError(
        '${clazz.displayName} takes an @CobaltParam and declares dependsOn. '
        'dependsOn orders init(), and this class is not built by init(): each '
        'getAsyncWithParam builds one, awaiting whatever it asks for. Drop the '
        'dependsOn.',
        clazz,
      );
    }
    if (isAsyncInit && !takesParams && lifetime == CobaltLifetime.transient) {
      if (isLazyAsync) {
        throw CobaltParseError(
          '${clazz.displayName} is transient and @CobaltInit(lazy: true). A '
          'lazy registration is one instance built by the first getAsync; a '
          'transient builds a new one on every call. Drop lazy — a transient '
          '@CobaltInit class is already built only when asked, by getAsync.',
          clazz,
        );
      }
      if (dependsOn.isNotEmpty) {
        throw CobaltParseError(
          '${clazz.displayName} is transient and declares dependsOn. dependsOn '
          'orders init(), and a transient @CobaltInit class is not built by '
          'init(): each getAsync builds one, awaiting whatever it asks for. '
          'Drop the dependsOn.',
          clazz,
        );
      }
    }
    if (isLazyAsync && dependsOn.isNotEmpty) {
      throw CobaltParseError(
        '${clazz.displayName} is @CobaltInit(lazy: true) and declares '
        'dependsOn. dependsOn orders init(), and a lazy class is not built by '
        'init(): it is built by the first getAsync, which awaits whatever it '
        'asks for. Drop the dependsOn.',
        clazz,
      );
    }

    final name = annotation.readString('name');
    final exposeAs = _exposeAsOf(annotation);
    final environments = environmentsOf(clazz);
    final properties = injectedFieldsOf(clazz);

    CobaltInjectableClass build(
      CobaltTypeRef type,
      List<FormalParameterElement> typed,
      List<CobaltInjectedProperty> properties, {
      CobaltTypeRef? exposeAs,
    }) => CobaltInjectableClass(
      type: type,
      lifetime: lifetime,
      name: name,
      exposeAs: exposeAs,
      isAsyncInit: isAsyncInit,
      isLazyAsync: isLazyAsync,
      dependsOn: dependsOn,
      environments: environments,
      dispose: dispose,
      constructorParameters: [
        for (final (index, parameter) in constructor.formalParameters.indexed)
          CobaltInjectedProperty(
            field: parameter.name ?? '',
            type: typeRefOf(typed[index].type),
            name: namedMatcher.firstOf(parameter)?.readString('name'),
            isNamed: parameter.isNamed,
            isParam: paramMatcher.matches(parameter),
            hasDefault: parameter.hasDefaultValue,
          ),
      ],
      properties: properties,
    );

    final exposed = instantiations.isEmpty
        ? null
        : _rawExposeAsOf(clazz, injectAnnotation);
    if (instantiations.isEmpty) {
      return [
        build(
          typeRefOfElement(clazz),
          constructor.formalParameters,
          properties,
          exposeAs: exposeAs,
        ),
      ];
    }
    return [
      for (final instantiation in instantiations)
        build(
          typeRefOf(instantiation),
          _instantiatedConstructorOf(
            instantiation,
            constructor,
          ).formalParameters,
          _instantiatedPropertiesOf(instantiation, properties),
          exposeAs: exposed == null
              ? null
              : _instantiatedExposeAs(clazz, instantiation, exposed),
        ),
    ];
  }

  /// The `@injected` fields of [clazz] as it declares them, a type parameter
  /// still a type parameter.
  ///
  /// [parseClass] reads them once per instantiation, `Repo<Note>` where the
  /// field says `Repo<T>`; the one `_$ClassName` mixin of a generic class is
  /// written against this declared form instead.
  List<CobaltInjectedProperty> declaredPropertiesOf(ClassElement clazz) =>
      injectedFieldsOf(clazz);

  /// The instantiations [clazz] registers, empty for a class without type
  /// parameters.
  List<InterfaceType> _instantiationsOf(
    ClassElement clazz,
    DartObject? injectAnnotation,
  ) {
    final values =
        injectAnnotation?.getField('instantiations')?.toListValue() ??
        const <DartObject>[];

    if (clazz.typeParameters.isEmpty) {
      if (values.isEmpty) return const [];
      throw CobaltParseError(
        '${clazz.displayName} lists instantiations but declares no type '
        'parameters, so there is nothing to instantiate. Drop instantiations.',
        clazz,
      );
    }

    if (values.isEmpty) {
      final parameters = clazz.typeParameters
          .map((parameter) => parameter.displayName)
          .join(', ');
      final example = clazz.typeParameters.map((_) => 'Note').join(', ');
      throw CobaltParseError(
        '${clazz.displayName} declares type parameters <$parameters>, so there '
        'is no single instantiation to register. Name the ones to register, '
        'as in @CobaltInject(instantiations: [${clazz.displayName}<$example>]), '
        'or annotate a concrete subtype.',
        clazz,
      );
    }

    final instantiations = <InterfaceType>[];
    for (final value in values) {
      final type = value.toTypeValue();
      final shown = type?.getDisplayString() ?? '$value';
      if (type is! InterfaceType ||
          type.element != clazz ||
          type.nullabilitySuffix == NullabilitySuffix.question) {
        throw CobaltParseError(
          '${clazz.displayName} lists $shown among its instantiations. Each '
          'entry has to be ${clazz.displayName} itself with its type '
          'arguments, such as ${clazz.displayName}<Note>.',
          clazz,
        );
      }
      final unusable = type.typeArguments.where(_isUnusableArgument);
      if (unusable.isNotEmpty) {
        throw CobaltParseError(
          '${clazz.displayName} lists $shown among its instantiations, and '
          '${unusable.first.getDisplayString()} is not a type argument Cobalt '
          'can register. A raw ${clazz.displayName} reads as '
          '${clazz.displayName}<dynamic>; spell out every type argument.',
          clazz,
        );
      }
      if (instantiations.contains(type)) {
        throw CobaltParseError(
          '${clazz.displayName} lists $shown twice among its instantiations. '
          'Name each one once.',
          clazz,
        );
      }
      instantiations.add(type);
    }
    return instantiations;
  }

  static bool _isUnusableArgument(DartType type) =>
      type is DynamicType ||
      type is NeverType ||
      type is InvalidType ||
      _mentionsTypeParameterOrInvalid(type);

  static bool _mentionsTypeParameterOrInvalid(DartType type) =>
      type is TypeParameterType ||
      type is InvalidType ||
      (type is InterfaceType &&
          type.typeArguments.any(_mentionsTypeParameterOrInvalid));

  /// [constructor] as a member of [instantiation], so its parameter types
  /// read `Store<Note>` where the declaration says `Store<T>`.
  ConstructorElement _instantiatedConstructorOf(
    InterfaceType instantiation,
    ConstructorElement constructor,
  ) => instantiation.constructors.firstWhere(
    (candidate) => candidate.baseElement == constructor.baseElement,
  );

  InterfaceElement? _rawExposeAsOf(
    ClassElement clazz,
    DartObject? injectAnnotation,
  ) {
    final type = injectAnnotation?.getField('exposeAs')?.toTypeValue();
    if (type == null) return null;
    final shown = type.getDisplayString();
    if (type is! InterfaceType || type.element.typeParameters.isEmpty) {
      throw CobaltParseError(
        '${clazz.displayName} lists instantiations and exposes them as $shown, '
        'which has no type parameters, so every instantiation would be '
        'registered under the same type. Expose them as a generic type the '
        'class implements, such as Store for Cache<T> implements Store<T>.',
        clazz,
      );
    }
    final parameters = type.element.typeParameters;
    final written = [
      for (final (index, argument) in type.typeArguments.indexed)
        if (argument is! DynamicType && argument != parameters[index].bound)
          argument,
    ];
    if (written.isNotEmpty) {
      throw CobaltParseError(
        '${clazz.displayName} lists instantiations and exposes them as $shown. '
        'Write exposeAs without type arguments, as exposeAs: '
        '${type.element.displayName}: each instantiation is exposed under '
        'its own, the ones it implements.',
        clazz,
      );
    }
    return type.element;
  }

  CobaltTypeRef _instantiatedExposeAs(
    ClassElement clazz,
    InterfaceType instantiation,
    InterfaceElement exposed,
  ) {
    final implemented = instantiation.asInstanceOf(exposed);
    if (implemented == null) {
      throw CobaltParseError(
        '${clazz.displayName} exposes ${instantiation.getDisplayString()} as '
        '${exposed.displayName}, which it does not implement.',
        clazz,
      );
    }
    return typeRefOf(implemented);
  }

  List<CobaltInjectedProperty> _instantiatedPropertiesOf(
    InterfaceType instantiation,
    List<CobaltInjectedProperty> properties,
  ) => [
    for (final property in properties)
      CobaltInjectedProperty(
        field: property.field,
        type: typeRefOf(instantiation.getGetter(property.field)!.returnType),
        name: property.name,
      ),
  ];

  ConstructorElement _constructorOf(ClassElement clazz) {
    if (clazz.isAbstract) {
      throw CobaltParseError(
        '${clazz.displayName} is abstract and cannot be constructed.',
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
    return constructor;
  }

  bool _hasInitMethod(ClassElement clazz) =>
      clazz.methods.any((method) => method.name == 'init') ||
      clazz.allSupertypes.any(
        (supertype) => supertype.methods.any((method) => method.name == 'init'),
      );

  /// The lifetime [annotation] asks for.
  ///
  /// An async class is retained unless it says transient: an `@CobaltInit`
  /// class is built once — by `init()`, or by the first `getAsync` when lazy —
  /// and a transient one by every `getAsync`.
  CobaltLifetime _lifetimeOf(
    DartObject annotation, {
    required bool isAsyncInit,
  }) {
    final index = annotation.readEnumIndex('lifetime');
    final declared = index == null ? null : CobaltLifetime.values[index];
    if (isAsyncInit) {
      return declared == CobaltLifetime.transient
          ? CobaltLifetime.transient
          : CobaltLifetime.lazySingleton;
    }
    return declared ?? CobaltLifetime.lazySingleton;
  }

  CobaltTypeRef? _exposeAsOf(DartObject annotation) {
    final type = annotation.getField('exposeAs')?.toTypeValue();
    return type == null ? null : typeRefOf(type);
  }

  List<CobaltTypeRef> _dependsOnOf(DartObject? initAnnotation) {
    final values = initAnnotation?.getField('dependsOn')?.toListValue();
    if (values == null) return const [];
    return [
      for (final value in values)
        if (value.toTypeValue() case final type?) typeRefOf(type),
    ];
  }
}
