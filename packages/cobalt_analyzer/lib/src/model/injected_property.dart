import 'package:cobalt_analyzer/src/model/type_ref.dart';

class CobaltInjectedProperty {
  const CobaltInjectedProperty({
    required this.field,
    required this.type,
    this.name,
    this.isNamed = false,
    this.isParam = false,
    this.hasDefault = false,
  });

  factory CobaltInjectedProperty.fromJson(Map<String, dynamic> json) =>
      CobaltInjectedProperty(
        field: json['field'] as String,
        type: CobaltTypeRef.fromJson(json['type'] as Map<String, dynamic>),
        name: json['name'] as String?,
        isNamed: json['isNamed'] as bool? ?? false,
        isParam: json['isParam'] as bool? ?? false,
        hasDefault: json['hasDefault'] as bool? ?? false,
      );

  final String field;
  final CobaltTypeRef type;
  final String? name;

  /// Whether the constructor takes this as a named parameter.
  ///
  /// The call has to be rebuilt the way it was declared: passing a named
  /// parameter positionally produces a generated file that does not compile.
  final bool isNamed;

  /// Whether the value comes from the call site rather than from the graph.
  ///
  /// Marked with `@CobaltParam`. Such a parameter is not a dependency: nothing
  /// registers it, it is no edge in the ordering, and it arrives through
  /// `getWithParam` instead.
  final bool isParam;

  /// Whether the constructor declares a default value for this parameter.
  ///
  /// The generator leaves such a parameter out of the call, so the default
  /// applies, when nothing in the graph registers its type; registered, it is
  /// injected like any other.
  final bool hasDefault;

  Map<String, dynamic> toJson() => {
    'field': field,
    'type': type.toJson(),
    'name': name,
    if (isNamed) 'isNamed': true,
    if (isParam) 'isParam': true,
    if (hasDefault) 'hasDefault': true,
  };
}
