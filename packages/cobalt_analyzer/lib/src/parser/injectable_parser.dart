import 'package:cobalt_analyzer/src/model/injectable_class.dart';
import 'package:cobalt_analyzer/src/model/injected_property.dart';
import 'package:cobalt_analyzer/src/model/type_ref.dart';
import 'package:cobalt_analyzer/src/parser/cobalt_matchers.dart';
import 'package:cobalt_analyzer/src/parser/dart_object_reader.dart';
import 'package:cobalt_analyzer/src/parser/dispose_reader.dart';
import 'package:cobalt_analyzer/src/parser/environment_reader.dart';
import 'package:cobalt_analyzer/src/parser/parse_error.dart';
import 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
import 'package:cobalt_annotations/cobalt_annotations.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

class CobaltInjectableParser {
  const CobaltInjectableParser();

  bool declares(ClassElement clazz) =>
      injectMatcher.matches(clazz) || initMatcher.matches(clazz);

  CobaltInjectableClass parseClass(ClassElement clazz) {
    final initAnnotation = initMatcher.firstOf(clazz);
    final isAsyncInit = initAnnotation != null;
    final annotation = injectMatcher.firstOf(clazz) ?? initAnnotation!;

    if (clazz.typeParameters.isNotEmpty) {
      final parameters = clazz.typeParameters
          .map((parameter) => parameter.displayName)
          .join(', ');
      throw CobaltParseError(
        '${clazz.displayName} declares type parameters <$parameters>, so there '
        'is no single instantiation to register. Annotate a concrete subtype, '
        'or expose one with @CobaltInject(exposeAs: ...).',
        clazz,
      );
    }

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

    if (injectMatcher.firstOf(clazz)?.readBool('lazyInit') ?? false) {
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

    return CobaltInjectableClass(
      type: typeRefOfElement(clazz),
      lifetime: lifetime,
      name: annotation.readString('name'),
      exposeAs: _exposeAsOf(annotation),
      isAsyncInit: isAsyncInit,
      isLazyAsync: isLazyAsync,
      dependsOn: dependsOn,
      environments: environmentsOf(clazz),
      dispose: dispose,
      constructorParameters: [
        for (final parameter in constructor.formalParameters)
          CobaltInjectedProperty(
            field: parameter.name ?? '',
            type: typeRefOf(parameter.type),
            name: namedMatcher.firstOf(parameter)?.readString('name'),
            isNamed: parameter.isNamed,
            isParam: paramMatcher.matches(parameter),
          ),
      ],
      properties: [
        for (final field in clazz.fields)
          if (injectedMatcher.matches(field)) _property(clazz, field),
      ],
    );
  }

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

  CobaltInjectedProperty _property(ClassElement clazz, FieldElement field) {
    if (field.isStatic) {
      throw CobaltParseError(
        '${clazz.displayName}.${field.displayName} is static and cannot be '
        'injected.',
        field,
      );
    }
    if (!field.isLate) {
      throw CobaltParseError(
        '${clazz.displayName}.${field.displayName} must be declared '
        '"late final" to receive property injection.',
        field,
      );
    }

    return CobaltInjectedProperty(
      field: field.displayName,
      type: typeRefOf(field.type),
      name:
          namedMatcher.firstOf(field)?.readString('name') ??
          injectedMatcher.firstOf(field)?.readString('name'),
    );
  }
}
