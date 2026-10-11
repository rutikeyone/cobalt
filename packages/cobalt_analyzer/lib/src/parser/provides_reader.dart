import 'package:cobalt_analyzer/src/model/provided_ref.dart';
import 'package:cobalt_analyzer/src/parser/dart_object_reader.dart';
import 'package:cobalt_analyzer/src/parser/parse_error.dart';
import 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

/// The `provides` list of a `@CobaltScopeRoot` or `@CobaltChildScope`.
List<CobaltProvidedRef> providesOf(DartObject annotation, ClassElement clazz) {
  final values = annotation.getField('provides')?.toListValue();
  if (values == null) return const [];
  return [for (final value in values) _provided(value, clazz)];
}

CobaltProvidedRef _provided(DartObject value, ClassElement clazz) {
  if (value.toTypeValue() case final type?) {
    return CobaltProvidedRef(type: typeRefOf(type));
  }
  if (value.getField('type')?.toTypeValue() case final type?) {
    return CobaltProvidedRef(
      type: typeRefOf(type),
      name: value.readString('name'),
    );
  }
  throw CobaltParseError(
    '${clazz.displayName} lists something in provides that is neither a '
    'type nor an CobaltProvided. Write the type itself, or '
    "CobaltProvided(Type, name: 'qualifier') when the registration is named.",
    clazz,
  );
}
