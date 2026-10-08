// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/fixes/make_init_lazy.dart';
import 'package:cobalt_lint/src/rules/depends_on_lazy_registration.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_support.dart';
import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MakeInitLazyTest);
  });
}

@reflectiveTest
class MakeInitLazyTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = DependsOnLazyRegistration();
    super.setUp();
  }

  Future<void> check(String annotation, String? expected) async {
    String source(String annotation) =>
        '''
$cobaltImport

@cobaltLazyInit
class Engine {
  Engine();
  Future<void> init() async {}
}

$annotation
class Search {
  Search();
  Future<void> init() async {}
}
''';

    expect(
      await fixed(source(annotation), MakeInitLazy.new),
      expected == null ? isNull : source(expected),
    );
  }

  void test_dependsOn_becomesLazy() async {
    await check('@CobaltInit(dependsOn: [Engine])', '@CobaltInit(lazy: true)');
  }

  void test_multiline_keepsItsShape() async {
    await check(
      '@CobaltInit(\n  dependsOn: [Engine],\n)',
      '@CobaltInit(\n  lazy: true,\n)',
    );
  }

  void test_explicitLazy_isNotFixed() async {
    await check('@CobaltInit(lazy: false, dependsOn: [Engine])', null);
  }
}
