import 'package:cobalt_analyzer/src/model/injected_property.dart';
import 'package:cobalt_analyzer/src/parser/cobalt_matchers.dart';
import 'package:cobalt_analyzer/src/parser/dart_object_reader.dart';
import 'package:cobalt_analyzer/src/parser/parse_error.dart';
import 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
import 'package:analyzer/dart/element/element.dart';

/// The `@injected` fields of [clazz], in declaration order.
///
/// Shared by every kind of class the generated `_$ClassName` mixin fills — a
/// registration and a decorator alike — so a field is read, and refused, the
/// same way wherever it sits.
List<CobaltInjectedProperty> injectedFieldsOf(ClassElement clazz) => [
  for (final field in clazz.fields)
    if (injectedMatcher.matches(field)) _injectedField(clazz, field),
];

CobaltInjectedProperty _injectedField(ClassElement clazz, FieldElement field) {
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
