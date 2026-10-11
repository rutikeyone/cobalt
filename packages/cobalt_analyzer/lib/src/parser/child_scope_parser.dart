import 'package:cobalt_analyzer/src/model/child_scope_class.dart';
import 'package:cobalt_analyzer/src/model/injected_property.dart';
import 'package:cobalt_analyzer/src/model/type_ref.dart';
import 'package:cobalt_analyzer/src/parser/cobalt_matchers.dart';
import 'package:cobalt_analyzer/src/parser/dart_object_reader.dart';
import 'package:cobalt_analyzer/src/parser/parse_error.dart';
import 'package:cobalt_analyzer/src/parser/provides_reader.dart';
import 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';

/// Reads a `@CobaltChildScope` marker.
class CobaltChildScopeParser {
  const CobaltChildScopeParser();

  bool declares(ClassElement clazz) => childScopeMatcher.matches(clazz);

  CobaltChildScopeClass parseClass(ClassElement clazz) {
    final annotation = childScopeMatcher.firstOf(clazz)!;
    final name = clazz.displayName;

    if (name.endsWith('Scope')) {
      final bare = name.substring(0, name.length - 'Scope'.length);
      throw CobaltParseError(
        '$name is a @CobaltChildScope marker whose name ends in Scope. The '
        'generator appends Scope to name the builder, so this one would be '
        '${name}Scope. Call the marker ${bare.isEmpty ? 'after what it holds' : bare}.',
        clazz,
      );
    }
    if (clazz.typeParameters.isNotEmpty) {
      throw CobaltParseError(
        '$name declares type parameters. A @CobaltChildScope marker names one '
        'scope, so it cannot be generic.',
        clazz,
      );
    }

    return CobaltChildScopeClass(
      type: typeRefOfElement(clazz),
      parent: _parentOf(annotation, clazz),
      values: _valuesOf(clazz),
      provides: providesOf(annotation, clazz),
    );
  }

  CobaltTypeRef? _parentOf(DartObject annotation, ClassElement clazz) {
    final parent = annotation.getField('parent')?.toTypeValue();
    if (parent == null) return null;
    final element = parent.element;
    if (element is! ClassElement || !childScopeMatcher.matches(element)) {
      throw CobaltParseError(
        '${clazz.displayName} names ${parent.getDisplayString()} as its parent, '
        'which is not a @CobaltChildScope marker. Name a marker, or leave '
        'parent out for a scope opened under the root.',
        clazz,
      );
    }
    if (element == clazz) {
      throw CobaltParseError(
        '${clazz.displayName} names itself as its parent.',
        clazz,
      );
    }
    return typeRefOfElement(element);
  }

  List<CobaltInjectedProperty> _valuesOf(ClassElement clazz) {
    final constructor = clazz.constructors
        .where((c) => c.isPublic && !c.isFactory)
        .firstOrNull;
    if (constructor == null) return const [];

    return [
      for (final parameter in constructor.formalParameters)
        _value(clazz, parameter),
    ];
  }

  CobaltInjectedProperty _value(
    ClassElement clazz,
    FormalParameterElement parameter,
  ) {
    final where = '${clazz.displayName}(${parameter.displayName})';
    if (parameter is! FieldFormalParameterElement) {
      throw CobaltParseError(
        '$where is not an initializing formal. Write this.${parameter.displayName}: '
        'each constructor parameter of a @CobaltChildScope marker is a value '
        'the scope registers, and the generated builder stores it the same way.',
        clazz,
      );
    }
    if (parameter.isOptional) {
      throw CobaltParseError(
        '$where is optional. Make it required: the generated builder repeats '
        'the constructor, and a default value would not travel with it.',
        clazz,
      );
    }
    if (parameter.type.nullabilitySuffix == NullabilitySuffix.question) {
      throw CobaltParseError(
        '$where is nullable, and a scope cannot register null. Make it '
        'non-nullable, or leave it out and register it by hand.',
        clazz,
      );
    }
    final field = clazz.getField(parameter.name ?? '');
    final named =
        namedMatcher.firstOf(parameter) ??
        (field == null ? null : namedMatcher.firstOf(field));
    return CobaltInjectedProperty(
      field: parameter.name ?? '',
      type: typeRefOf(parameter.type),
      name: named?.readString('name'),
      isNamed: parameter.isNamed,
    );
  }
}
