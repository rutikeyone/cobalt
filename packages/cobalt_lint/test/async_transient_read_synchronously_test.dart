// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/async_transient_read_synchronously.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AsyncTransientReadSynchronouslyTest);
  });
}

const _runtime = r'''
abstract base class CobaltResolver {
  T get<T extends Object>({String? name});
  T? getOrNull<T extends Object>({String? name});
  List<T> getAll<T extends Object>();
  Future<T> getAsync<T extends Object>({String? name});
}

final class CobaltScope extends CobaltResolver {
  @override
  T get<T extends Object>({String? name}) => throw UnimplementedError();
  @override
  T? getOrNull<T extends Object>({String? name}) => null;
  @override
  List<T> getAll<T extends Object>() => const [];
  @override
  Future<T> getAsync<T extends Object>({String? name}) =>
      throw UnimplementedError();
}
''';

const _flutter = r'''
class BuildContext {}

extension CobaltBuildContext on BuildContext {
  T cobalt<T extends Object>({String? name}) => throw UnimplementedError();
  List<T> cobaltAll<T extends Object>() => const [];
  Future<T> cobaltAsync<T extends Object>({String? name}) =>
      throw UnimplementedError();
}
''';

const _runtimeImport = "import 'package:cobalt/cobalt.dart';";

const _flutterImport = "import 'package:cobalt_flutter/cobalt_flutter.dart';";

/// The annotations and the runtime — what most sources here need.
const _imports =
    '''
$cobaltImport
$_runtimeImport
''';

const _report = '''
@cobaltTransient
@cobaltInit
class Report {
  Report();
  Future<void> init() async {}
}
''';

@reflectiveTest
class AsyncTransientReadSynchronouslyTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    newPackage('cobalt').addFile('lib/cobalt.dart', _runtime);
    newPackage('cobalt_flutter').addFile('lib/cobalt_flutter.dart', _flutter);
    newPackage('engine').addFile('lib/engine.dart', 'class Engine {}');
    rule = AsyncTransientReadSynchronously();
    super.setUp();
  }

  /// Expects one report, on the method name at the [nth] occurrence of
  /// [call] in [source].
  Future<void> _reportsOn(String source, String call, String method) =>
      assertDiagnostics(source, [lint(source.indexOf(call), method.length)]);

  void test_getOnAResolver_isReported() async {
    const source =
        '''
$_imports
$_report
void read(CobaltResolver resolver) {
  resolver.get<Report>();
}
''';
    await _reportsOn(source, 'get<Report>', 'get');
  }

  void test_anInferredTypeArgument_isReported() async {
    const source =
        '''
$_imports
$_report
void read(CobaltScope scope) {
  final Report report = scope.get();
  print(report);
}
''';
    await _reportsOn(source, 'get();', 'get');
  }

  void test_getOrNullAndGetAllOnAScope_areReported() async {
    const source =
        '''
$_imports
$_report
void read(CobaltScope scope) {
  scope.getOrNull<Report>();
  scope.getAll<Report>();
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('getOrNull<Report>'), 'getOrNull'.length),
      lint(source.indexOf('getAll<Report>'), 'getAll'.length),
    ]);
  }

  void test_contextCobalt_isReported() async {
    const source =
        '''
$cobaltImport
$_flutterImport
$_report
void read(BuildContext context) {
  context.cobalt<Report>();
  context.cobaltAll<Report>();
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('cobalt<Report>'), 'cobalt'.length),
      lint(source.indexOf('cobaltAll<Report>'), 'cobaltAll'.length),
    ]);
  }

  void test_aTransientModuleMemberReturningAFuture_isReported() async {
    const source =
        '''
$_imports
import 'package:engine/engine.dart';

@cobaltModule
class EngineModule {
  const EngineModule();

  @cobaltTransient
  Future<Engine> engine() async => Engine();
}

void read(CobaltResolver resolver) {
  resolver.get<Engine>();
}
''';
    await _reportsOn(source, 'get<Engine>', 'get');
  }

  void test_getAsync_isClean() async {
    await assertNoDiagnostics('''
$_imports
$_flutterImport
$_report
void read(CobaltResolver resolver, BuildContext context) {
  resolver.getAsync<Report>();
  context.cobaltAsync<Report>();
}
''');
  }

  void test_aSynchronousTransient_isClean() async {
    await assertNoDiagnostics('''
$_imports
@cobaltTransient
class Report {
  Report();
}

void read(CobaltResolver resolver) {
  resolver.get<Report>();
}
''');
  }

  void test_aLazyAsyncSingleton_isClean() async {
    await assertNoDiagnostics('''
$_imports
@cobaltLazyInit
class Engine {
  Engine();
  Future<void> init() async {}
}

void read(CobaltResolver resolver) {
  resolver.get<Engine>();
}
''');
  }

  void test_anAsyncClassTakingACallSiteValue_isNotThisRule() async {
    await assertNoDiagnostics('''
$_imports
@cobaltTransient
@cobaltInit
class Document {
  Document({@cobaltParam required this.id});
  final int id;
  Future<void> init() async {}
}

void read(CobaltResolver resolver) {
  resolver.get<Document>();
}
''');
  }

  void test_aGetThatIsNotCobalts_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport
$_report
class Box {
  T get<T>() => throw 0;
}

void read(Box box) {
  box.get<Report>();
}
''');
  }

  void test_aNameTwoDeclarationsClaim_staysSilent() async {
    newFile('$testPackageLibPath/other.dart', '''
class Report {}
''');
    await assertNoDiagnostics('''
$_imports
$_report
void read(CobaltResolver resolver) {
  resolver.get<Report>();
}
''');
  }
}
