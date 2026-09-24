// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/environment_needs_a_registration.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(EnvironmentNeedsARegistrationTest);
  });
}

@reflectiveTest
class EnvironmentNeedsARegistrationTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = EnvironmentNeedsARegistration();
    super.setUp();
  }

  void test_onAnInjectable_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
@CobaltEnvironment.dev
class FakeApi {}
''');
  }

  void test_onABootstrapStep_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltBootstrap
@CobaltEnvironment.prod
class ReportCrashes {
  void run() {}
}
''');
  }

  void test_onAnAsyncInitializer_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInit
@CobaltEnvironment.prod
class Telemetry {
  Future<void> init() async {}
}
''');
  }

  void test_aCustomEnvironmentName_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
@CobaltEnvironment('canary')
class CanaryApi {}
''');
  }

  void test_withoutAnyRegistration_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

@CobaltEnvironment.dev
class FakeApi {}
''',
      [lint(91, 7)],
    );
  }

  void test_unannotatedClass_isClean() async {
    await assertNoDiagnostics(r'''
class FakeApi {}
''');
  }
}
