import 'package:cobalt_analyzer/src/model/type_ref.dart';

/// An `@CobaltHookAll` class: a `CobaltHook` the generated root scope adds.
class CobaltHookClass {
  const CobaltHookClass({
    required this.type,
    required this.target,
    this.order = 0,
    this.environments = const {},
  });

  factory CobaltHookClass.fromJson(Map<String, dynamic> json) =>
      CobaltHookClass(
        type: CobaltTypeRef.fromJson(json['type'] as Map<String, dynamic>),
        target: CobaltTypeRef.fromJson(json['target'] as Map<String, dynamic>),
        order: json['order'] as int? ?? 0,
        environments: {
          for (final e in json['environments'] as List<dynamic>? ?? const [])
            e as String,
        },
      );

  /// The hook class itself.
  final CobaltTypeRef type;

  /// The type argument of the `CobaltHook` it implements: what it sees.
  final CobaltTypeRef target;

  /// Its place among the generated hooks, lowest first.
  final int order;

  /// Environment names it is restricted to, empty when it applies in all.
  final Set<String> environments;

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    'target': target.toJson(),
    'order': order,
    'environments': [...environments],
  };
}
