// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/marker_value_needs_a_name.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MarkerValueNeedsANameTest);
  });
}

@reflectiveTest
class MarkerValueNeedsANameTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = MarkerValueNeedsAName();
    super.setUp();
  }

  void test_everyPrimitiveWithoutAName_isReported() async {
    const source =
        '''
$cobaltImport

@CobaltChildScope()
class Session {
  const Session(this.id, this.attempt, this.score, this.limit, this.isGuest);
  final String id;
  final int attempt;
  final double score;
  final num limit;
  final bool isGuest;
}
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('this.id'),
        7,
        messageContainsAll: ["'id' is registered", 'bare type String'],
      ),
      lint(source.indexOf('this.attempt'), 12),
      lint(source.indexOf('this.score'), 10),
      lint(source.indexOf('this.limit'), 10),
      lint(source.indexOf('this.isGuest'), 12),
    ]);
  }

  void test_aNameOnTheParameter_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@CobaltChildScope()
class Session {
  const Session(@Named('userId') this.id);
  final String id;
}
''');
  }

  void test_aNameOnTheField_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@CobaltChildScope()
class Session {
  const Session(this.id);
  @Named('userId')
  final String id;
}
''');
  }

  void test_aTypeOfItsOwn_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

class UserId {
  const UserId(this.value);
  final String value;
}

@CobaltChildScope()
class Session {
  const Session(this.id);
  final UserId id;
}
''');
  }

  void test_aClassThatIsNoMarker_isClean() async {
    await assertNoDiagnostics('''
class Session {
  const Session(this.id);
  final String id;
}
''');
  }
}
