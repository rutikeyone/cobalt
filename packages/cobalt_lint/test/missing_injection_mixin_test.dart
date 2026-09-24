// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/missing_injection_mixin.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingInjectionMixinTest);
  });
}

@reflectiveTest
class MissingInjectionMixinTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = MissingInjectionMixin();
    super.setUp();
  }

  void test_missingMixin_isReported() async {
    await assertDiagnostics(
      r'''
import 'package:cobalt_annotations/cobalt_annotations.dart';

@cobaltInject
class Bloc {
  @injected
  late final String value;
}
''',
      [lint(82, 4)],
    );
  }

  void test_mixinPresent_isClean() async {
    await assertNoDiagnostics(r'''
import 'package:cobalt_annotations/cobalt_annotations.dart';

mixin _$Bloc {}

@cobaltInject
class Bloc with _$Bloc {
  @injected
  late final String value;
}
''');
  }

  void test_noInjectedFields_isClean() async {
    await assertNoDiagnostics(r'''
import 'package:cobalt_annotations/cobalt_annotations.dart';

@cobaltInject
class Service {
  final String value = '';
}
''');
  }

  /// The mixin is written only for a class the container registers, so on a
  /// class nothing registers this rule stays quiet and
  /// `cobalt_injected_field_needs_an_injectable` speaks instead.
  void test_classNothingRegisters_isNotThisRule() async {
    await assertNoDiagnostics(r'''
import 'package:cobalt_annotations/cobalt_annotations.dart';

class Orphan {
  @injected
  late final String value;
}
''');
  }

  void test_asyncInitClass_isReportedToo() async {
    await assertDiagnostics(
      r'''
import 'package:cobalt_annotations/cobalt_annotations.dart';

@CobaltInit()
class Warmer {
  @injected
  late final String value;
}
''',
      [lint(82, 6)],
    );
  }
}
