// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/fixes/make_late_final.dart';
import 'package:cobalt_lint/src/rules/injected_field_must_be_late_final.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_support.dart';
import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MakeLateFinalTest);
  });
}

@reflectiveTest
class MakeLateFinalTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = InjectedFieldMustBeLateFinal();
    super.setUp();
  }

  Future<void> check(String field, String? expected) async {
    String source(String field) =>
        '''
$cobaltImport

class Bloc {
  @injected
  $field
}
''';

    expect(
      await fixed(source(field), MakeLateFinal.new),
      expected == null ? isNull : source(expected),
    );
  }

  void test_final_becomesLateFinal() async {
    await check('final String value;', 'late final String value;');
  }

  void test_typed_becomesLateFinal() async {
    await check('String? value;', 'late final String? value;');
  }

  void test_var_becomesLateFinal() async {
    await check('var value;', 'late final value;');
  }

  void test_late_becomesLateFinal() async {
    await check('late String value;', 'late final String value;');
  }

  void test_lateVar_becomesLateFinal() async {
    await check('late var value;', 'late final value;');
  }

  void test_covariant_keepsItsPlace() async {
    await check(
      'covariant String value;',
      'covariant late final String value;',
    );
  }

  void test_static_isNotFixed() async {
    await check('static late final String value;', null);
  }

  void test_initializer_isNotFixed() async {
    await check("final String value = '';", null);
  }
}
