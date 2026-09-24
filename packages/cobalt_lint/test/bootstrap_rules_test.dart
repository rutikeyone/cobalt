// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/bootstrap_requires_run_method.dart';
import 'package:cobalt_lint/src/rules/bootstrap_step_cannot_inject.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(BootstrapRequiresRunMethodTest);
    defineReflectiveTests(BootstrapStepCannotInjectTest);
  });
}

@reflectiveTest
class BootstrapRequiresRunMethodTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = BootstrapRequiresRunMethod();
    super.setUp();
  }

  void test_withRunMethod_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltBootstrap
class BindPlatform {
  String get name => 'bind';
  void run() {}
}
''');
  }

  void test_missingRunMethod_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

@cobaltBootstrap
class BindPlatform {
  String get name => 'bind';
}
''',
      [lint(85, 12)],
    );
  }
}

@reflectiveTest
class BootstrapStepCannotInjectTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = BootstrapStepCannotInject();
    super.setUp();
  }

  void test_noParameters_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltBootstrap
class BindPlatform {
  BindPlatform();
  void run() {}
}
''');
  }

  void test_optionalParameters_areClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltBootstrap
class BindPlatform {
  BindPlatform({this.verbose = false});
  final bool verbose;
  void run() {}
}
''');
  }

  void test_requiredParameter_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

class Logger {}

@cobaltBootstrap
class BindPlatform {
  BindPlatform(this.logger);
  final Logger logger;
  void run() {}
}
''',
      [lint(102, 12)],
    );
  }
}
