// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/registration_is_never_released.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RegistrationIsNeverReleasedTest);
  });
}

@reflectiveTest
class RegistrationIsNeverReleasedTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    stubCobaltRuntime(this);
    rule = RegistrationIsNeverReleased();
    super.setUp();
  }

  void test_disposeMethodWithoutTheInterface_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

@cobaltInject
class Notes {
  void dispose() {}
}
''',
      [lint(82, 5)],
    );
  }

  void test_closeMethodWithoutTheInterface_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

@cobaltInject
class Session {
  Future<void> close() async {}
}
''',
      [lint(82, 7)],
    );
  }

  void test_inheritedFromABaseClass_isReported() async {
    // The shape of every Bloc and every ChangeNotifier: the closing method
    // belongs to a base class the author did not write.
    await assertDiagnostics(
      '''
$cobaltImport

abstract class Notifier {
  void dispose() {}
}

@cobaltInject
class Notes extends Notifier {}
''',
      [lint(131, 5)],
    );
  }

  void test_declaringTheInterface_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport
$cobaltRuntimeImport

@cobaltInject
class Notes implements Disposable {
  @override
  void dispose() {}
}
''');
  }

  void test_declaringTheAsyncInterface_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport
$cobaltRuntimeImport

@cobaltInject
class Session implements AsyncDisposable {
  Future<void> close() async {}

  @override
  Future<void> dispose() => close();
}
''');
  }

  void test_namingADisposeFunction_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

void closeNotes(Notes notes) {}

@CobaltInject(dispose: closeNotes)
class Notes {
  void dispose() {}
}
''');
  }

  void test_aTransient_isClean() async {
    // The scope never retains one, so there is nothing for it to release.
    await assertNoDiagnostics('''
$cobaltImport

@cobaltTransient
class Notes {
  void dispose() {}
}
''');
  }

  void test_aMethodThatIsNotATeardown_isClean() async {
    // `close` here answers something and takes an argument. Reporting it would
    // be the rule guessing at meaning from a name.
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
class Notes {
  bool close(String reason) => true;
}
''');
  }

  void test_nothingToClose_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
class Notes {}
''');
  }

  void test_unregisteredClass_isClean() async {
    await assertNoDiagnostics(r'''
class Notes {
  void dispose() {}
}
''');
  }
}
