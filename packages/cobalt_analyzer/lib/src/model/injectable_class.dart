import 'package:cobalt_analyzer/src/model/function_ref.dart';
import 'package:cobalt_analyzer/src/model/injected_property.dart';
import 'package:cobalt_analyzer/src/model/provider_ref.dart';
import 'package:cobalt_analyzer/src/model/type_ref.dart';
import 'package:cobalt_annotations/cobalt_annotations.dart';

class CobaltInjectableClass {
  const CobaltInjectableClass({
    required this.type,
    required this.lifetime,
    required this.constructorParameters,
    required this.properties,
    this.name,
    this.exposeAs,
    this.isAsyncInit = false,
    this.isLazyAsync = false,
    this.dependsOn = const [],
    this.environments = const {},
    this.provider,
    this.dispose,
  });

  factory CobaltInjectableClass.fromJson(
    Map<String, dynamic> json,
  ) => CobaltInjectableClass(
    type: CobaltTypeRef.fromJson(json['type'] as Map<String, dynamic>),
    lifetime: CobaltLifetime.values.byName(json['lifetime'] as String),
    constructorParameters: [
      for (final p in json['constructorParameters'] as List<dynamic>)
        CobaltInjectedProperty.fromJson(p as Map<String, dynamic>),
    ],
    properties: [
      for (final p in json['properties'] as List<dynamic>)
        CobaltInjectedProperty.fromJson(p as Map<String, dynamic>),
    ],
    name: json['name'] as String?,
    exposeAs: json['exposeAs'] == null
        ? null
        : CobaltTypeRef.fromJson(json['exposeAs'] as Map<String, dynamic>),
    isAsyncInit: json['isAsyncInit'] as bool? ?? false,
    isLazyAsync: json['isLazyAsync'] as bool? ?? false,
    dependsOn: [
      for (final d in json['dependsOn'] as List<dynamic>? ?? const [])
        CobaltTypeRef.fromJson(d as Map<String, dynamic>),
    ],
    environments: {
      for (final e in json['environments'] as List<dynamic>? ?? const [])
        e as String,
    },
    provider: json['provider'] == null
        ? null
        : CobaltProviderRef.fromJson(json['provider'] as Map<String, dynamic>),
    dispose: json['dispose'] == null
        ? null
        : CobaltFunctionRef.fromJson(json['dispose'] as Map<String, dynamic>),
  );

  final CobaltTypeRef type;
  final CobaltLifetime lifetime;
  final List<CobaltInjectedProperty> constructorParameters;
  final List<CobaltInjectedProperty> properties;
  final String? name;
  final CobaltTypeRef? exposeAs;
  final bool isAsyncInit;

  /// Whether this async registration is built by the first `getAsync` rather
  /// than during `init()`. Only ever true together with [isAsyncInit].
  final bool isLazyAsync;
  final List<CobaltTypeRef> dependsOn;

  /// Environment names this registration is restricted to, empty when it
  /// belongs to every graph.
  final Set<String> environments;

  /// The module member that builds this, or null when [type] is constructed
  /// directly.
  final CobaltProviderRef? provider;

  /// A function that closes the instance at teardown, for a type that cannot
  /// say how itself.
  final CobaltFunctionRef? dispose;

  CobaltTypeRef get exposedType => exposeAs ?? type;

  /// The same declaration with [dependsOn] replaced.
  ///
  /// The generator uses this to fill in ordering it worked out itself, for a
  /// module member that cannot state it in an annotation.
  CobaltInjectableClass withDependsOn(List<CobaltTypeRef> dependsOn) =>
      CobaltInjectableClass(
        type: type,
        lifetime: lifetime,
        constructorParameters: constructorParameters,
        properties: properties,
        name: name,
        exposeAs: exposeAs,
        isAsyncInit: isAsyncInit,
        isLazyAsync: isLazyAsync,
        dependsOn: dependsOn,
        environments: environments,
        provider: provider,
        dispose: dispose,
      );

  /// How this declaration is named in diagnostics.
  ///
  /// For a class that is the class itself; for a module member, [type] is what
  /// the member *returns*, which alone would read as "Dio and Dio both
  /// register Dio".
  String get label {
    final origin = provider;
    return origin == null
        ? type.name
        : '${origin.module.name}.${origin.member}';
  }

  bool get hasPropertyInjection => properties.isNotEmpty;

  /// The constructor parameters the call site supplies, in order.
  ///
  /// Empty for the ordinary case. When it is not, the class is registered as
  /// a parameterized factory and these become the fields of its record.
  List<CobaltInjectedProperty> get callSiteValues => [
    for (final parameter in constructorParameters)
      if (parameter.isParam) parameter,
  ];

  /// Whether anything in this class comes from the call site.
  bool get takesCallSiteValues =>
      constructorParameters.any((parameter) => parameter.isParam);

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    'lifetime': lifetime.name,
    'constructorParameters': [
      for (final p in constructorParameters) p.toJson(),
    ],
    'properties': [for (final p in properties) p.toJson()],
    'name': name,
    'exposeAs': exposeAs?.toJson(),
    'isAsyncInit': isAsyncInit,
    'isLazyAsync': isLazyAsync,
    'dependsOn': [for (final d in dependsOn) d.toJson()],
    'environments': [...environments],
    'provider': provider?.toJson(),
    'dispose': dispose?.toJson(),
  };
}
