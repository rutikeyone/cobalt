// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/read_does_not_match_registration.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ReadDoesNotMatchRegistrationTest);
  });
}

const _runtime = r'''
abstract base class CobaltResolver {
  T get<T extends Object>({String? name});
  T? getOrNull<T extends Object>({String? name});
  List<T> getAll<T extends Object>();
  Future<T> getAsync<T extends Object>({String? name});
  T getWithParam<T extends Object, P extends Object>(P param, {String? name});
  Future<T> getAsyncWithParam<T extends Object, P extends Object>(
    P param, {
    String? name,
  });
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
  @override
  T getWithParam<T extends Object, P extends Object>(P param, {String? name}) =>
      throw UnimplementedError();
  @override
  Future<T> getAsyncWithParam<T extends Object, P extends Object>(
    P param, {
    String? name,
  }) => throw UnimplementedError();
}
''';

const _flutter = r'''
class BuildContext {}

extension CobaltBuildContext on BuildContext {
  T cobalt<T extends Object>({String? name}) => throw UnimplementedError();
  T cobaltWithParam<T extends Object, P extends Object>(
    P param, {
    String? name,
  }) => throw UnimplementedError();
  Future<T> cobaltAsyncWithParam<T extends Object, P extends Object>(
    P param, {
    String? name,
  }) => throw UnimplementedError();
}
''';

const _imports =
    '''
$cobaltImport
import 'package:cobalt/cobalt.dart';
''';

const _flutterImport = "import 'package:cobalt_flutter/cobalt_flutter.dart';";

const _classes = '''
@cobaltInject
class Editor {
  Editor({@cobaltParam required this.id});
  final int id;
}

@cobaltInit
class Document {
  Document({@cobaltParam required this.id});
  final int id;
  Future<void> init() async {}
}

@cobaltInject
class Clock {
  Clock();
}
''';

@reflectiveTest
class ReadDoesNotMatchRegistrationTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    newPackage('cobalt').addFile('lib/cobalt.dart', _runtime);
    newPackage('cobalt_flutter').addFile('lib/cobalt_flutter.dart', _flutter);
    rule = ReadDoesNotMatchRegistration();
    super.setUp();
  }

  void test_getOnARegistrationWithAValue_isReported() async {
    const source =
        '''
$_imports
$_classes
void read(CobaltScope scope) {
  scope.get<Editor>();
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf('get<Editor>'),
        'get'.length,
        messageContainsAll: ["'Editor' takes a value", 'get<Editor>()'],
      ),
    ]);
  }

  void test_getAsyncAndGetOrNullOnAValue_areReported() async {
    const source =
        '''
$_imports
$_classes
void read(CobaltResolver resolver) {
  resolver.getAsync<Editor>();
  resolver.getOrNull<Document>();
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('getAsync<Editor>'), 'getAsync'.length),
      lint(source.indexOf('getOrNull<Document>'), 'getOrNull'.length),
    ]);
  }

  void test_contextCobaltOnAValue_isReported() async {
    const source =
        '''
$cobaltImport
$_flutterImport
$_classes
void read(BuildContext context) {
  context.cobalt<Editor>();
}
''';
    await assertDiagnostics(source, [
      lint(source.indexOf('cobalt<Editor>'), 'cobalt'.length),
    ]);
  }

  void test_getWithParamOnAnAsyncValue_isReported() async {
    const source =
        '''
$_imports
$_flutterImport
$_classes
void read(CobaltScope scope, BuildContext context) {
  scope.getWithParam<Document, ({int id})>((id: 1));
  context.cobaltWithParam<Document, ({int id})>((id: 1));
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf('getWithParam<Document'),
        'getWithParam'.length,
        messageContainsAll: ['built asynchronously'],
      ),
      lint(
        source.indexOf('cobaltWithParam<Document'),
        'cobaltWithParam'.length,
      ),
    ]);
  }

  void test_aValuePassedToARegistrationWithout_isReported() async {
    const source =
        '''
$_imports
$_flutterImport
$_classes
void read(CobaltScope scope, BuildContext context) {
  scope.getWithParam<Clock, int>(1);
  scope.getAsyncWithParam<Clock, int>(1);
  context.cobaltWithParam<Clock, int>(1);
}
''';
    await assertDiagnostics(source, [
      lint(
        source.indexOf('getWithParam<Clock'),
        'getWithParam'.length,
        messageContainsAll: ["'Clock' takes no value"],
      ),
      lint(
        source.indexOf('getAsyncWithParam<Clock'),
        'getAsyncWithParam'.length,
      ),
      lint(source.indexOf('cobaltWithParam<Clock'), 'cobaltWithParam'.length),
    ]);
  }

  void test_theMatchingReads_areClean() async {
    await assertNoDiagnostics('''
$_imports
$_flutterImport
$_classes
void read(CobaltScope scope, BuildContext context) {
  scope.getWithParam<Editor, ({int id})>((id: 1));
  scope.getAsyncWithParam<Editor, ({int id})>((id: 1));
  scope.getAsyncWithParam<Document, ({int id})>((id: 1));
  context.cobaltAsyncWithParam<Document, ({int id})>((id: 1));
  scope.get<Clock>();
  context.cobalt<Clock>();
}
''');
  }

  void test_aTypeTwoDeclarationsRegister_isClean() async {
    await assertNoDiagnostics('''
$_imports
abstract class Api {}

@CobaltInject(exposeAs: Api)
class LiveApi implements Api {
  LiveApi({@cobaltParam required this.region});
  final String region;
}

@CobaltInject(exposeAs: Api, name: 'fake')
class FakeApi implements Api {
  FakeApi();
}

void read(CobaltScope scope) {
  scope.get<Api>(name: 'fake');
  scope.getWithParam<Api, ({String region})>((region: 'eu'));
}
''');
  }

  void test_aModuleMember_isClean() async {
    await assertNoDiagnostics('''
$_imports
class Engine {}

@cobaltModule
class EngineModule {
  const EngineModule();

  @cobaltInject
  Engine engine() => Engine();
}

void read(CobaltScope scope) {
  scope.getWithParam<Engine, int>(1);
}
''');
  }

  void test_anUnknownType_isClean() async {
    await assertNoDiagnostics('''
import 'package:cobalt/cobalt.dart';
class Elsewhere {}

void read(CobaltScope scope) {
  scope.get<Elsewhere>();
  scope.getWithParam<Elsewhere, int>(1);
}
''');
  }
}
