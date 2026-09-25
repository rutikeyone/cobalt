import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/emitters/container_source_emitter.dart';

const appImport = 'package:app/app.dart';

CobaltTypeRef ref(
  String name, {
  List<CobaltTypeRef> of = const [],
  bool isNullable = false,
}) => CobaltTypeRef(
  name: name,
  import: appImport,
  typeArguments: of,
  isNullable: isNullable,
);

CobaltInjectedProperty dep(
  String type, {
  String? name,
  bool isNullable = false,
  bool isNamed = false,
  String? field,
}) => CobaltInjectedProperty(
  field: field ?? type.toLowerCase(),
  type: ref(type, isNullable: isNullable),
  name: name,
  isNamed: isNamed,
);

/// A constructor parameter the call site supplies, as `@CobaltParam` marks it.
CobaltInjectedProperty arg(String field, String type, {bool isNamed = true}) =>
    CobaltInjectedProperty(
      field: field,
      type: CobaltTypeRef(name: type, import: 'dart:core'),
      isNamed: isNamed,
      isParam: true,
    );

CobaltInjectableClass declare(
  String type, {
  CobaltLifetime lifetime = CobaltLifetime.lazySingleton,
  List<CobaltInjectedProperty> constructor = const [],
  List<CobaltInjectedProperty> properties = const [],
  String? name,
  CobaltTypeRef? exposeAs,
  bool isAsyncInit = false,
  bool isLazyAsync = false,
  List<CobaltTypeRef> dependsOn = const [],
  Set<String> environments = const {},
  CobaltFunctionRef? dispose,
}) => CobaltInjectableClass(
  type: ref(type),
  lifetime: lifetime,
  constructorParameters: constructor,
  properties: properties,
  name: name,
  exposeAs: exposeAs,
  isAsyncInit: isAsyncInit || isLazyAsync,
  isLazyAsync: isLazyAsync,
  dependsOn: dependsOn,
  environments: environments,
  dispose: dispose,
);

CobaltBootstrapStepClass step(
  String type, {
  int order = 0,
  Set<String> environments = const {},
}) => CobaltBootstrapStepClass(
  type: ref(type),
  order: order,
  environments: environments,
);

CobaltInjectableClass provide(
  String module,
  String member,
  String returns, {
  CobaltLifetime lifetime = CobaltLifetime.lazySingleton,
  List<CobaltInjectedProperty> parameters = const [],
  String? name,
  CobaltTypeRef? exposeAs,
  bool isAsyncInit = false,
  bool isLazyAsync = false,
  bool isGetter = false,
  Set<String> environments = const {},
  CobaltFunctionRef? dispose,
}) => CobaltInjectableClass(
  type: ref(returns),
  lifetime: lifetime,
  constructorParameters: parameters,
  properties: const [],
  name: name,
  exposeAs: exposeAs,
  isAsyncInit: isAsyncInit || isLazyAsync,
  isLazyAsync: isLazyAsync,
  environments: environments,
  provider: CobaltProviderRef(
    module: ref(module),
    member: member,
    isGetter: isGetter,
  ),
  dispose: dispose,
);

CobaltProvidedRef provided(String type, {String? name}) =>
    CobaltProvidedRef(type: ref(type), name: name);

CobaltScopeRootClass scopeRoot(
  String type, {
  String name = 'root',
  List<CobaltProvidedRef> provides = const [],
}) => CobaltScopeRootClass(type: ref(type), name: name, provides: provides);

/// A decorator of [target] whose constructor takes the wrapped instance
/// first, then [dependencies].
CobaltDecoratorClass decorator(
  String type,
  String target, {
  List<CobaltInjectedProperty> dependencies = const [],
  String? name,
  int? order,
  Set<String> environments = const {},
  bool innerIsNamed = false,
  String import = appImport,
}) => CobaltDecoratorClass(
  type: CobaltTypeRef(name: type, import: import),
  target: ref(target),
  inner: 'inner',
  name: name,
  order: order,
  environments: environments,
  constructorParameters: [
    CobaltInjectedProperty(
      field: 'inner',
      type: ref(target),
      isNamed: innerIsNamed,
    ),
    ...dependencies,
  ],
);

String generate(
  List<CobaltInjectableClass> injectables, {
  List<CobaltBootstrapStepClass> bootstrap = const [],
  List<CobaltScopeRootClass> scopeRoots = const [],
  List<CobaltDecoratorClass> decorators = const [],
}) => const ContainerSourceEmitter().emit(
  CobaltLibraryDeclarations(
    injectables: injectables,
    bootstrapSteps: bootstrap,
    scopeRoots: scopeRoots,
    decorators: decorators,
  ),
);

List<String> decorationsOf(String source) => source
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.startsWith('scope.decorate'))
    .toList();

List<String> registrationsOf(String source) => source
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.startsWith('scope.register'))
    .toList();
