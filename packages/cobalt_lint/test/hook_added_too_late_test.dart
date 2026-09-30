// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/hook_added_too_late.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(HookAddedTooLateTest);
  });
}

const _runtime = r'''
abstract base class CobaltHook<T extends Object> {
  const CobaltHook();
}

abstract interface class CobaltFactory<T extends Object> {}

abstract base class CobaltResolver {
  T get<T extends Object>({String? name});
}

final class CobaltScope extends CobaltResolver {
  @override
  T get<T extends Object>({String? name}) => throw UnimplementedError();
  Future<void> init() async {}
  CobaltScope push(String name) => this;
  void hookAll<T extends Object>(CobaltHook<T> hook) {}
  void registerEagerSingleton<T extends Object>(CobaltFactory<T> factory) {}
  void registerLazySingleton<T extends Object>(CobaltFactory<T> factory) {}
}
''';

const _prelude = '''
import 'package:cobalt/cobalt.dart';

final class Seen extends CobaltHook<Object> {
  const Seen();
}

final class Make implements CobaltFactory<Object> {
  const Make();
}
''';

@reflectiveTest
class HookAddedTooLateTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('cobalt').addFile('lib/cobalt.dart', _runtime);
    rule = HookAddedTooLate();
    super.setUp();
  }

  Future<void> _reportsOn(String source, {int nth = 0}) {
    var at = -1;
    for (var i = 0; i <= nth; i++) {
      at = source.indexOf('hookAll', at + 1);
    }
    return assertDiagnostics(source, [lint(at, 'hookAll'.length)]);
  }

  void test_afterAnEagerRegistrationInTheSameCascade_isReported() async {
    const source =
        '''
$_prelude
void build(CobaltScope scope) {
  scope
    ..registerEagerSingleton<Object>(const Make())
    ..hookAll<Object>(const Seen());
}
''';
    await _reportsOn(source);
  }

  void test_afterAGetInAnEarlierStatement_isReported() async {
    const source =
        '''
$_prelude
void build(CobaltScope scope) {
  scope.get<Object>();
  scope.hookAll<Object>(const Seen());
}
''';
    await _reportsOn(source);
  }

  void test_afterAnAwaitedInit_isReported() async {
    const source =
        '''
$_prelude
Future<void> build(CobaltScope scope) async {
  await scope.init();
  scope.hookAll<Object>(const Seen());
}
''';
    await _reportsOn(source);
  }

  void test_afterAnEagerRegistrationInAnEarlierCascade_isReported() async {
    const source =
        '''
$_prelude
void build(CobaltScope scope) {
  scope..registerLazySingleton<Object>(const Make())
    ..registerEagerSingleton<Object>(const Make());
  scope..hookAll<Object>(const Seen());
}
''';
    await _reportsOn(source);
  }

  void test_beforeEverything_isClean() async {
    await assertNoDiagnostics('''
$_prelude
void build(CobaltScope scope) {
  scope
    ..hookAll<Object>(const Seen())
    ..registerEagerSingleton<Object>(const Make());
  scope.get<Object>();
}
''');
  }

  void test_afterALazyRegistration_isClean() async {
    await assertNoDiagnostics('''
$_prelude
void build(CobaltScope scope) {
  scope
    ..registerLazySingleton<Object>(const Make())
    ..hookAll<Object>(const Seen());
}
''');
  }

  void test_aBuildOnAnotherScope_isClean() async {
    await assertNoDiagnostics('''
$_prelude
void build(CobaltScope app, CobaltScope other) {
  other.get<Object>();
  app.hookAll<Object>(const Seen());
}
''');
  }

  void test_aBuildInsideAClosure_isClean() async {
    await assertNoDiagnostics('''
$_prelude
void build(CobaltScope scope) {
  void later() => scope.get<Object>();
  scope.hookAll<Object>(const Seen());
  later();
}
''');
  }
}
