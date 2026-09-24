// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/injected_field_must_be_late_final.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(InjectedFieldMustBeLateFinalTest);
  });
}

@reflectiveTest
class InjectedFieldMustBeLateFinalTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = InjectedFieldMustBeLateFinal();
    super.setUp();
  }

  void test_lateFinal_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

class Bloc {
  @injected
  late final String value;
}
''');
  }

  void test_mutableField_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

class Bloc {
  @injected
  String? value;
}
''',
      [lint(77, 26)],
    );
  }

  void test_finalWithoutLate_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

class Bloc {
  @injected
  final String value = '';
}
''',
      [lint(77, 36)],
    );
  }

  void test_staticField_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

class Bloc {
  @injected
  static late final String value = '';
}
''',
      [lint(77, 48)],
    );
  }

  void test_unannotatedField_isClean() async {
    await assertNoDiagnostics(r'''
class Bloc {
  String? value;
}
''');
  }
}
