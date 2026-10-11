import 'package:cobalt_analyzer/src/model/injected_property.dart';
import 'package:cobalt_analyzer/src/model/provided_ref.dart';
import 'package:cobalt_analyzer/src/model/type_ref.dart';

/// A class annotated with `@CobaltChildScope`.
class CobaltChildScopeClass {
  const CobaltChildScopeClass({
    required this.type,
    this.parent,
    this.values = const [],
    this.provides = const [],
  });

  factory CobaltChildScopeClass.fromJson(Map<String, dynamic> json) =>
      CobaltChildScopeClass(
        type: CobaltTypeRef.fromJson(json['type'] as Map<String, dynamic>),
        parent: json['parent'] == null
            ? null
            : CobaltTypeRef.fromJson(json['parent'] as Map<String, dynamic>),
        values: [
          for (final v in json['values'] as List<dynamic>? ?? const [])
            CobaltInjectedProperty.fromJson(v as Map<String, dynamic>),
        ],
        provides: [
          for (final p in json['provides'] as List<dynamic>? ?? const [])
            CobaltProvidedRef.fromJson(p as Map<String, dynamic>),
        ],
      );

  /// The marker class.
  final CobaltTypeRef type;

  /// The marker of the scope this one opens under, or null for the root.
  final CobaltTypeRef? parent;

  /// The constructor parameters of the marker, in order: what the scope is
  /// opened with, each registered in it as a value.
  final List<CobaltInjectedProperty> values;

  /// Registrations made in this scope by hand.
  final List<CobaltProvidedRef> provides;

  /// The name of the builder the generator writes for it.
  String get builderName => '${type.name}Scope';

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    'parent': parent?.toJson(),
    'values': [for (final v in values) v.toJson()],
    'provides': [for (final p in provides) p.toJson()],
  };
}
