// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/depends_on_lazy_registration.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DependsOnLazyRegistrationTest);
  });
}

@reflectiveTest
class DependsOnLazyRegistrationTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = DependsOnLazyRegistration();
    super.setUp();
  }

  static const _engine = '''
@cobaltLazyInit
class Engine {
  Engine();
  Future<void> init() async {}
}
''';

  void test_waitingForALazyRegistration_isReported() async {
    const source =
        '''
$cobaltImport

$_engine
@CobaltInit(dependsOn: [Engine])
class Search {
  Search();
  Future<void> init() async {}
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('class Search') + 6, 'Search'.length),
    ]);
  }

  void test_waitingForAnEagerAsyncRegistration_isQuiet() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltLazyInit
class Archive {
  Archive();
  Future<void> init() async {}
}

@cobaltInit
class Engine {
  Engine();
  Future<void> init() async {}
}

@CobaltInit(dependsOn: [Engine])
class Search {
  Search();
  Future<void> init() async {}
}
''');
  }

  void test_aLazyClassDeclaringDependsOn_isLeftToTheBuild() async {
    await assertNoDiagnostics('''
$cobaltImport

$_engine
@CobaltInit(lazy: true, dependsOn: [Engine])
class Search {
  Search();
  Future<void> init() async {}
}
''');
  }

  void test_aLazyRegistrationInAnotherFile_isSeen() async {
    newFile('$testPackageLibPath/engine.dart', '''
$cobaltImport

$_engine
''');
    const source =
        '''
$cobaltImport
import 'engine.dart';

@CobaltInit(dependsOn: [Engine])
class Search {
  Search();
  Future<void> init() async {}
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('class Search') + 6, 'Search'.length),
    ]);
  }
}
