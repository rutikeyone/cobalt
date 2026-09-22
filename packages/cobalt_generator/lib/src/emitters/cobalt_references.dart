import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:code_builder/code_builder.dart';

const cobaltUrl = 'package:cobalt/cobalt.dart';

Reference cobaltRef(String symbol) => refer(symbol, cobaltUrl);

TypeReference cobaltGeneric(String symbol, Reference argument) => TypeReference(
  (b) => b
    ..symbol = symbol
    ..url = cobaltUrl
    ..types.add(argument),
);

Reference typeReferenceOf(CobaltTypeRef type) {
  if (type.typeArguments.isEmpty) return refer(type.name, type.import);
  return TypeReference(
    (b) => b
      ..symbol = type.name
      ..url = type.import
      ..types.addAll([for (final a in type.typeArguments) typeReferenceOf(a)]),
  );
}

/// The type of one field of a call-site record.
///
/// Unlike [typeReferenceOf] this keeps the `?`. That function deliberately
/// drops it, because it also builds `registerLazySingleton<T>` and
/// `CobaltKey(T)`, where nullability would change the registration. A record
/// field is the opposite case: dropping it there narrows the argument, so a
/// constructor willing to take null would be handed a type that cannot
/// express it.
Reference recordFieldTypeOf(CobaltTypeRef type) {
  if (!type.isNullable) return typeReferenceOf(type);
  return TypeReference(
    (b) => b
      ..symbol = type.name
      ..url = type.import
      ..isNullable = true
      ..types.addAll([for (final a in type.typeArguments) typeReferenceOf(a)]),
  );
}

/// Refers to a function the generated code calls by name.
Expression functionReferenceOf(CobaltFunctionRef function) {
  final owner = function.owner;
  return owner == null
      ? refer(function.name, function.import)
      : refer(owner, function.import).property(function.name);
}

/// Emits the resolve for one dependency.
///
/// A nullable dependency reads through `getOrNull`, so a graph that does not
/// register it injects null instead of failing. The type argument stays
/// non-nullable either way — `getOrNull<Foo>()` returns `Foo?`, and
/// `CobaltResolver` bounds every type parameter to `Object`.
///
/// The branch belongs here rather than in [typeReferenceOf]: that one also
/// builds `registerLazySingleton<T>` and `CobaltKey(T)`, where a `?` would
/// change the registration itself.
Expression resolveCall(CobaltInjectedProperty dependency) {
  final name = dependency.name;
  return refer('resolver')
      .property(dependency.type.isNullable ? 'getOrNull' : 'get')
      .call(
        const [],
        {if (name != null) 'name': literalString(name)},
        [typeReferenceOf(dependency.type)],
      );
}

/// Emits the resolve for a dependency on a lazy async registration.
///
/// Awaited through `getAsync`, which builds it on first use. A nullable one
/// is checked with `isRegistered` first, so a graph without it still injects
/// null rather than failing.
Expression awaitedResolveCall(CobaltInjectedProperty dependency) {
  final name = dependency.name;
  final named = {if (name != null) 'name': literalString(name)};
  final types = [typeReferenceOf(dependency.type)];
  final awaited = refer(
    'resolver',
  ).property('getAsync').call(const [], named, types).awaited;
  if (!dependency.type.isNullable) return awaited;
  return refer('resolver')
      .property('isRegistered')
      .call(const [], named, types)
      .conditional(awaited, literalNull);
}

/// The key a registration is found under: the type's signature and the name.
///
/// Nullability is not part of it — a `Foo?` dependency reads the `Foo` key.
String registrationKey(CobaltTypeRef type, String? name) =>
    '${type.signature}#${name ?? ''}';

/// [registrationKey] for what [dependency] asks for.
String keyOfDependency(CobaltInjectedProperty dependency) =>
    registrationKey(dependency.type, dependency.name);

Expression get defaultEnvironment =>
    cobaltRef('CobaltEnvironment').property('defaultEnvironment');

Expression environmentGuard(Set<String> environments) =>
    refer('environment').property('matches').call([
      literalConstSet(
        (environments.toList()..sort()).toSet(),
        refer('String', 'dart:core'),
      ),
    ]);

Code guardedBy(Set<String> environments, Code statement) => environments.isEmpty
    ? statement
    : Block.of([
        const Code('if ('),
        environmentGuard(environments).code,
        const Code(') {'),
        statement,
        const Code('}'),
      ]);
