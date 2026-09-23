import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';

const cobaltAnnotationsStub = r'''
// The order matters: the parser reads this field by enum index, so a stub
// that lists them differently maps every lifetime to the wrong one and
// says nothing about it.
enum CobaltLifetime { transient, lazySingleton, singleton }

class CobaltInject {
  const CobaltInject({
    this.name,
    this.exposeAs,
    this.dispose,
    this.lifetime = CobaltLifetime.lazySingleton,
    this.lazyInit = false,
  });
  final String? name;
  final Type? exposeAs;
  final Function? dispose;
  final CobaltLifetime lifetime;
  final bool lazyInit;
}

const cobaltInject = CobaltInject();

const cobaltTransient = CobaltInject(lifetime: CobaltLifetime.transient);

class Named {
  const Named(this.name);
  final String name;
}

class CobaltProvided {
  const CobaltProvided(this.type, {this.name});
  final Type type;
  final String? name;
}

class CobaltScopeRoot {
  const CobaltScopeRoot({this.name = 'root', this.provides = const <Object>[]});
  final String name;
  final List<Object> provides;
}

class CobaltParam {
  const CobaltParam();
}

const cobaltParam = CobaltParam();

class Injected {
  const Injected({this.name});
  final String? name;
}

const injected = Injected();

class CobaltBootstrap {
  const CobaltBootstrap({this.order = 0});
  final int order;
}

const cobaltBootstrap = CobaltBootstrap();

class CobaltInit {
  const CobaltInit({this.dependsOn = const <Type>[], this.lazy = false});
  final List<Type> dependsOn;
  final bool lazy;
}

const cobaltInit = CobaltInit();

const cobaltLazyInit = CobaltInit(lazy: true);

class CobaltModule {
  const CobaltModule();
}

const cobaltModule = CobaltModule();

class CobaltEnvironment {
  const CobaltEnvironment(this.name);
  final String name;
  static const dev = CobaltEnvironment('dev');
  static const prod = CobaltEnvironment('prod');
}
''';

const cobaltImport =
    "import 'package:cobalt_annotations/cobalt_annotations.dart';";

/// What the runtime recognises as closeable.
///
/// A stub rather than the real `package:cobalt`, for the same reason the
/// annotations are one: these tests drive rules, not a resolver over the whole
/// workspace.
const cobaltRuntimeStub = r'''
abstract interface class Disposable {
  void dispose();
}

abstract interface class AsyncDisposable {
  Future<void> dispose();
}
''';

const cobaltRuntimeImport = "import 'package:cobalt/cobalt.dart';";

void stubCobaltRuntime(AnalysisRuleTest test) {
  test.newPackage('cobalt').addFile('lib/cobalt.dart', cobaltRuntimeStub);
}

void stubCobaltAnnotations(AnalysisRuleTest test) {
  test
      .newPackage('cobalt_annotations')
      .addFile('lib/cobalt_annotations.dart', cobaltAnnotationsStub);
}
