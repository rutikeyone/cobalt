// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/override_needs_type_argument.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(OverrideNeedsTypeArgumentTest);
  });
}

const _runtime = r'''
class CobaltOverride<T extends Object> {
  const CobaltOverride.value(T this.value);
  const CobaltOverride.lazy(Object this.value);
  final Object? value;
}

class CobaltParamOverride<T extends Object, P extends Object> {
  const CobaltParamOverride(this.factory);
  final Object factory;
}
''';

const _import = "import 'package:cobalt/cobalt.dart';";

const _types = '''
class Clock {}
class FixedClock implements Clock {}
''';

@reflectiveTest
class OverrideNeedsTypeArgumentTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('cobalt').addFile('lib/cobalt.dart', _runtime);
    rule = OverrideNeedsTypeArgument();
    super.setUp();
  }

  Future<void> _reportsOn(String source, String written) => assertDiagnostics(
    source,
    [lint(source.indexOf(RegExp('$written[.(]')), written.length)],
  );

  void test_insideAList_isReported() async {
    await _reportsOn('''
$_import
$_types
final overrides = <CobaltOverride<Object>>[
  CobaltOverride.value(FixedClock()),
];
''', 'CobaltOverride');
  }

  void test_onItsOwn_isReported() async {
    await _reportsOn('''
$_import
$_types
final replacement = CobaltOverride.value(FixedClock());
''', 'CobaltOverride');
  }

  void test_aParameterizedOverride_isReported() async {
    await _reportsOn('''
$_import
$_types
final replacement = CobaltParamOverride(Object());
''', 'CobaltParamOverride');
  }

  void test_aNamedTypeArgument_isQuiet() async {
    await assertNoDiagnostics('''
$_import
$_types
final overrides = <CobaltOverride<Object>>[
  CobaltOverride<Clock>.value(FixedClock()),
  CobaltOverride<Clock>.lazy(Object()),
];
''');
  }

  void test_aClassOfTheSameNameElsewhere_isQuiet() async {
    await assertNoDiagnostics('''
class CobaltOverride<T extends Object> {
  const CobaltOverride.value(this.value);
  final T value;
}
final replacement = CobaltOverride.value(1);
''');
  }
}
