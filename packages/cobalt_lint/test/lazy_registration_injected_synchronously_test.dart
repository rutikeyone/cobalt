// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/lazy_registration_injected_synchronously.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(LazyRegistrationInjectedSynchronouslyTest);
  });
}

@reflectiveTest
class LazyRegistrationInjectedSynchronouslyTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    newPackage('engine').addFile('lib/engine.dart', 'class Engine {}');
    rule = LazyRegistrationInjectedSynchronously();
    super.setUp();
  }

  static const _engine = '''
@cobaltLazyInit
class Engine {
  Engine();
  Future<void> init() async {}
}
''';

  Future<void> _reportsOn(String source, String className) => assertDiagnostics(
    source,
    [lint(source.indexOf('class $className') + 6, className.length)],
  );

  void test_syncConstructorDependency_isReported() async {
    await _reportsOn('''
$cobaltImport

$_engine
@cobaltInject
class Search {
  Search(this.engine);
  final Engine engine;
}
''', 'Search');
  }

  void test_eagerAsyncConstructorDependency_isReported() async {
    await _reportsOn('''
$cobaltImport

@CobaltInit(lazy: true)
class Engine {
  Engine();
  Future<void> init() async {}
}

@cobaltInit
class Warmup {
  Warmup(this.engine);
  final Engine engine;
  Future<void> init() async {}
}
''', 'Warmup');
  }

  void test_injectedField_isReportedEvenOnALazyClass() async {
    await _reportsOn('''
$cobaltImport

$_engine
@cobaltLazyInit
class Search {
  Search();
  @injected
  late final Engine engine;
  Future<void> init() async {}
}
''', 'Search');
  }

  void test_lazyConsumer_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

$_engine
@cobaltLazyInit
class Search {
  Search(this.engine);
  final Engine engine;
  Future<void> init() async {}
}
''');
  }

  void test_callSiteValue_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

$_engine
@cobaltTransient
class Search {
  Search({@cobaltParam required this.engine});
  final Engine engine;
}
''');
  }

  void test_lazyModuleMember_isReportedOnItsConsumer() async {
    await _reportsOn('''
$cobaltImport
import 'package:engine/engine.dart';

@cobaltModule
class EngineModule {
  const EngineModule();

  @CobaltInject(lazyInit: true)
  Future<Engine> engine() async => Engine();
}

@cobaltInject
class Search {
  Search(this.engine);
  final Engine engine;
}
''', 'Search');
  }

  void test_lazyInAnotherFile_isReported() async {
    newFile('$testPackageLibPath/engine.dart', '''
$cobaltImport

$_engine''');

    await _reportsOn('''
$cobaltImport

import 'engine.dart';

@cobaltInject
class Search {
  Search(this.engine);
  final Engine engine;
}
''', 'Search');
  }

  void test_aNameTwoDeclarationsClaim_staysSilent() async {
    newFile('$testPackageLibPath/other.dart', '''
class Engine {}
''');

    await assertNoDiagnostics('''
$cobaltImport

$_engine
@cobaltInject
class Search {
  Search(this.engine);
  final Engine engine;
}
''');
  }

  void test_noLazyRegistrations_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
class Engine {}

@cobaltInject
class Search {
  Search(this.engine);
  final Engine engine;
}
''');
  }
}
