// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/registration_is_not_generated.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RegistrationIsNotGeneratedTest);
  });
}

@reflectiveTest
class RegistrationIsNotGeneratedTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = RegistrationIsNotGenerated();
    super.setUp();
  }

  void generated(String body) =>
      newFile('$testPackageLibPath/cobalt.g.dart', '''
// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:test/test.dart' as _i137;

$body
''');

  static const source =
      '''
$cobaltImport

@cobaltInject
class Clock {}
''';

  void test_beforeTheFirstBuild_isClean() async {
    await assertNoDiagnostics(source);
  }

  void test_aClassTheContainerBuilds_isClean() async {
    generated('Object clock() => _i137.Clock();');

    await assertNoDiagnostics(source);
  }

  void test_aClassAnnotatedAfterTheBuild_isReported() async {
    generated('Object other() => _i137.Calendar();');

    await assertDiagnostics(source, [lint(source.indexOf('Clock {}'), 5)]);
  }

  void test_aPrivateFactoryOfTheSameName_doesNotCount() async {
    generated('final class _ClockFactory {}');

    await assertDiagnostics(source, [lint(source.indexOf('Clock {}'), 5)]);
  }

  void test_aModuleAddedAfterTheBuild_isReported() async {
    generated('Object other() => _i137.Calendar();');
    const module =
        '''
$cobaltImport

class Client {}

@cobaltModule
class NetworkModule {
  const NetworkModule();

  @cobaltInject
  Client get client => Client();
}
''';

    await assertDiagnostics(module, [
      lint(module.indexOf('NetworkModule {'), 13),
    ]);
  }

  void test_aClassWithoutAnnotation_isClean() async {
    generated('Object other() => _i137.Calendar();');

    await assertNoDiagnostics('''
class Clock {}
''');
  }
}
