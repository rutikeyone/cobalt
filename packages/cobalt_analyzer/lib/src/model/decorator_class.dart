import 'package:cobalt_analyzer/src/model/injected_property.dart';
import 'package:cobalt_analyzer/src/model/type_ref.dart';

/// A class the container builds around a registration instead of registering.
///
/// Kept apart from `CobaltInjectableClass` on purpose: a decorator claims no
/// key of its own, and every check that groups declarations by key would
/// otherwise take it for a second registration of its target.
class CobaltDecoratorClass {
  const CobaltDecoratorClass({
    required this.type,
    required this.target,
    required this.inner,
    required this.constructorParameters,
    this.name,
    this.order,
    this.environments = const {},
  });

  factory CobaltDecoratorClass.fromJson(Map<String, dynamic> json) =>
      CobaltDecoratorClass(
        type: CobaltTypeRef.fromJson(json['type'] as Map<String, dynamic>),
        target: CobaltTypeRef.fromJson(json['target'] as Map<String, dynamic>),
        inner: json['inner'] as String,
        constructorParameters: [
          for (final p in json['constructorParameters'] as List<dynamic>)
            CobaltInjectedProperty.fromJson(p as Map<String, dynamic>),
        ],
        name: json['name'] as String?,
        order: json['order'] as int?,
        environments: {
          for (final e in json['environments'] as List<dynamic>? ?? const [])
            e as String,
        },
      );

  /// The decorator class itself.
  final CobaltTypeRef type;

  /// The registered type it wraps.
  final CobaltTypeRef target;

  /// The field of the constructor parameter that receives the wrapped
  /// instance.
  final String inner;

  /// Every constructor parameter in declaration order, [inner] included.
  final List<CobaltInjectedProperty> constructorParameters;

  /// The name of the registration it wraps, when that one is named.
  final String? name;

  /// Its place among decorators of the same registration, lowest innermost.
  final int? order;

  /// Environment names it is restricted to, empty when it applies in all.
  final Set<String> environments;

  /// The parameters resolved from the scope — everything but [inner].
  List<CobaltInjectedProperty> get dependencies => [
    for (final parameter in constructorParameters)
      if (parameter.field != inner) parameter,
  ];

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    'target': target.toJson(),
    'inner': inner,
    'constructorParameters': [
      for (final p in constructorParameters) p.toJson(),
    ],
    'name': name,
    'order': order,
    'environments': [...environments],
  };
}
