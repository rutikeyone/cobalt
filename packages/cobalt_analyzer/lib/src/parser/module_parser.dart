import 'package:cobalt_analyzer/src/model/injectable_class.dart';
import 'package:cobalt_analyzer/src/model/injected_property.dart';
import 'package:cobalt_analyzer/src/model/provider_ref.dart';
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
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

/// Reads an `@CobaltModule` class into one registration per annotated member.
///
/// This is the only parser that is one-to-many: a module class is not itself
/// registered, it is a place to hang registrations of types the package does
/// not own.
class CobaltModuleParser {
  const CobaltModuleParser();

  bool declares(ClassElement clazz) => moduleMatcher.matches(clazz);

  List<CobaltInjectableClass> parseClass(ClassElement clazz) {
    _assertUsable(clazz);
    final module = typeRefOfElement(clazz);

    return [
      for (final member in [...clazz.getters, ...clazz.methods])
        if (injectMatcher.matches(member)) _parseMember(clazz, module, member),
    ];
  }

  void _assertUsable(ClassElement clazz) {
    if (clazz.isAbstract) {
      throw CobaltParseError(
        '${clazz.displayName} is abstract, so its members cannot be called. '
        'A module is an ordinary class with a const constructor.',
        clazz,
      );
    }
    if (clazz.typeParameters.isNotEmpty) {
      throw CobaltParseError(
        '${clazz.displayName} declares type parameters, so there is no single '
        'instance to call its members on.',
        clazz,
      );
    }
    final usable = clazz.constructors.any(
      (constructor) =>
          constructor.isPublic &&
          !constructor.isFactory &&
          constructor.isConst &&
          constructor.formalParameters.isEmpty &&
          _isUnnamed(constructor),
    );
    if (!usable) {
      throw CobaltParseError(
        '${clazz.displayName} needs a public const constructor taking no '
        'arguments, so the generated factory can hold '
        'const ${clazz.displayName}() and carry no state of its own.',
        clazz,
      );
    }
  }

  static bool _isUnnamed(ConstructorElement constructor) {
    final name = constructor.name;
    return name == null || name.isEmpty || name == 'new';
  }

  CobaltInjectableClass _parseMember(
    ClassElement clazz,
    CobaltTypeRef module,
    ExecutableElement member,
  ) {
    final where = '${clazz.displayName}.${member.displayName}';

    if (initMatcher.matches(member)) {
      throw CobaltParseError(
        '$where is annotated with @CobaltInit, which a module member does not '
        'take. Return Future<T> instead — that is what makes it async.',
        member,
      );
    }
    if (member.isStatic) {
      throw CobaltParseError(
        '$where is static. Module members are called on '
        'const ${clazz.displayName}(), so they have to be instance members.',
        member,
      );
    }
    if (member.isAbstract) {
      throw CobaltParseError(
        '$where is abstract, so there is no body to call. Register the class '
        'itself with @CobaltInject, and publish it under another type with '
        '@CobaltInject(exposeAs: ...).',
        member,
      );
    }
    if (member is MethodElement && member.typeParameters.isNotEmpty) {
      throw CobaltParseError(
        '$where declares type parameters, so there is no single '
        'instantiation to register.',
        member,
      );
    }

    final annotation = injectMatcher.firstOf(member)!;
    final produced = _producedType(member, where);
    final isAsync = member.returnType.isDartAsyncFuture;
    final lifetime = _lifetimeOf(annotation, isAsync: isAsync);
    final dispose = disposeOf(annotation, where, member);

    if (dispose != null && lifetime == CobaltLifetime.transient && !isAsync) {
      throw CobaltParseError(
        '$where is transient and also names a dispose function. The scope '
        'does not retain a transient, so it could never call it.',
        member,
      );
    }

    final isLazyAsync = annotation.readBool('lazyInit');
    if (isLazyAsync && !isAsync) {
      throw CobaltParseError(
        '$where is marked lazyInit but does not return a Future. lazyInit '
        'defers an async build to the first getAsync; a synchronous member is '
        'already built on first use by the default lifetime. Drop lazyInit.',
        member,
      );
    }

    return CobaltInjectableClass(
      type: produced,
      lifetime: lifetime,
      name: annotation.readString('name'),
      exposeAs: _exposeAsOf(annotation),
      isAsyncInit: isAsync,
      isLazyAsync: isLazyAsync,
      environments: environmentsOf(member),
      constructorParameters: [
        for (final parameter in member.formalParameters)
          _parameter(parameter, where, member),
      ],
      properties: const [],
      provider: CobaltProviderRef(
        module: module,
        member: member.displayName,
        isGetter: member is GetterElement,
      ),
      dispose: dispose,
    );
  }

  /// The type the member registers, with one `Future` layer removed.
  ///
  /// A member returning `Future<T>` registers `T` and is built during startup;
  /// nothing else in Cobalt treats `Future` specially, so leaving it wrapped
  /// would register `Future<T>` and leave every consumer of `T` unsatisfied.
  CobaltTypeRef _producedType(ExecutableElement member, String where) {
    final returnType = member.returnType;
    var produced = returnType;

    if (returnType.isDartAsyncFuture) {
      final arguments = returnType is InterfaceType
          ? returnType.typeArguments
          : const <DartType>[];
      // A bare `Future` is `Future<dynamic>`, so it arrives here with an
      // argument rather than without one.
      if (arguments.length != 1 || arguments.single is DynamicType) {
        throw CobaltParseError(
          '$where returns a bare Future, so there is no type to register. '
          'Return Future<T> naming what it produces.',
          member,
        );
      }
      produced = arguments.single;
    }

    if (produced is DynamicType ||
        produced is VoidType ||
        produced is NeverType ||
        produced.element == null) {
      throw CobaltParseError(
        '$where returns ${produced.getDisplayString()}, which is not a type '
        'Cobalt can register. Return a class.',
        member,
      );
    }

    if (produced.nullabilitySuffix == NullabilitySuffix.question) {
      throw CobaltParseError(
        '$where returns ${produced.getDisplayString()}, and a registration '
        'cannot be nullable — a nullable type marks a *dependency* optional, '
        'not a provider. Return the non-nullable type.',
        member,
      );
    }

    return typeRefOf(produced);
  }

  CobaltInjectedProperty _parameter(
    FormalParameterElement parameter,
    String where,
    ExecutableElement member,
  ) {
    if (paramMatcher.matches(parameter)) {
      throw CobaltParseError(
        '$where takes an @CobaltParam. A module registers types you did not '
        'write, and a call-site value belongs to a class you did — put '
        '@CobaltParam on its constructor instead.',
        member,
      );
    }
    if (parameter.isOptional) {
      throw CobaltParseError(
        '$where takes the optional parameter ${parameter.displayName}. Every '
        'parameter is resolved from the scope, so there is nothing for an '
        'optional one to mean.',
        member,
      );
    }
    return CobaltInjectedProperty(
      field: parameter.name ?? '',
      type: typeRefOf(parameter.type),
      name: namedMatcher.firstOf(parameter)?.readString('name'),
      isNamed: parameter.isNamed,
    );
  }

  CobaltLifetime _lifetimeOf(DartObject annotation, {required bool isAsync}) {
    if (isAsync) return CobaltLifetime.lazySingleton;
    final index = annotation.readEnumIndex('lifetime');
    return index == null
        ? CobaltLifetime.lazySingleton
        : CobaltLifetime.values[index];
  }

  CobaltTypeRef? _exposeAsOf(DartObject annotation) {
    final type = annotation.getField('exposeAs')?.toTypeValue();
    return type == null ? null : typeRefOf(type);
  }
}
