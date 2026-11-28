// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/decorator_misses_a_shadowing_scope.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DecoratorMissesAShadowingScopeTest);
  });
}

const _decorator =
    '''
$cobaltImport

import 'api.dart';

@CobaltDecorates(Api)
class LoggedApi implements Api {
  LoggedApi(this.inner);
  final Api inner;
}
''';

@reflectiveTest
class DecoratorMissesAShadowingScopeTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    newPackage('http').addFile('lib/http.dart', 'class Client {}');
    rule = DecoratorMissesAShadowingScope();
    super.setUp();
  }

  void _api(
    String registrations, {
    String session = '''
@CobaltChildScope()
class Session {
  const Session();
}''',
  }) => newFile('$testPackageLibPath/api.dart', '''
$cobaltImport

abstract interface class Api {}

$session

$registrations
''');

  void test_aChildScopeShadowingTheDecoratedRoot_isReported() async {
    _api('''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}

@CobaltInject(exposeAs: Api, scope: Session)
class FakeApi implements Api {}
''');

    await assertDiagnostics(_decorator, [
      lint(
        _decorator.indexOf('LoggedApi implements'),
        9,
        messageContainsAll: ['the child scope Session registers Api too'],
        correctionContains: 'or give it another name',
      ),
    ]);
  }

  void test_aModuleMemberShadowingTheDecoratedRoot_isReported() async {
    _api('''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}

class FakeApi implements Api {}

@cobaltModule
class FakeModule {
  const FakeModule();

  @CobaltInject(scope: Session)
  Api api() => FakeApi();
}
''');

    await assertDiagnostics(_decorator, [
      lint(_decorator.indexOf('LoggedApi implements'), 9),
    ]);
  }

  void test_aRootRegistrationNobodyShadows_isClean() async {
    _api('''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}
''');

    await assertNoDiagnostics(_decorator);
  }

  void test_aDecoratorOfWhatOnlyAChildRegisters_isClean() async {
    _api('''
@CobaltInject(exposeAs: Api, scope: Session)
class FakeApi implements Api {}
''');

    await assertNoDiagnostics(_decorator);
  }

  void test_aChildRegistrationUnderAnotherName_isClean() async {
    _api('''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}

@CobaltInject(exposeAs: Api, name: 'fake', scope: Session)
class FakeApi implements Api {}
''');

    await assertNoDiagnostics(_decorator);
  }

  void test_aDecoratorOfEveryNameMissingANamedChild_isReported() async {
    _api('''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}

@CobaltInject(exposeAs: Api, name: 'fake', scope: Session)
class FakeApi implements Api {}
''');
    const source =
        '''
$cobaltImport

import 'api.dart';

@CobaltDecorates(Api, allNames: true)
class LoggedApi implements Api {
  LoggedApi(this.inner);
  final Api inner;
}
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('LoggedApi implements'),
        9,
        correctionContains: 'another one does not help',
      ),
    ]);
  }

  void test_registrationsInEnvironments_areClean() async {
    _api('''
@CobaltInject(exposeAs: Api)
@CobaltEnvironment.prod
class LiveApi implements Api {}

@CobaltInject(exposeAs: Api, scope: Session)
@CobaltEnvironment.dev
class FakeApi implements Api {}
''');

    await assertNoDiagnostics(_decorator);
  }

  void test_aNameTwoTypesShare_isClean() async {
    _api('''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}

@CobaltInject(exposeAs: Api, scope: Session)
class FakeApi implements Api {}
''');
    newFile('$testPackageLibPath/other.dart', '''
abstract interface class Api {}
''');

    await assertNoDiagnostics(_decorator);
  }

  void test_aMarkerValueShadowingTheDecoratedRoot_isReported() async {
    _api(
      '''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}
''',
      session: '''
@CobaltChildScope()
class Session {
  const Session(this.api);
  final Api api;
}''',
    );

    await assertDiagnostics(_decorator, [
      lint(_decorator.indexOf('LoggedApi implements'), 9),
    ]);
  }

  void test_aNamedMarkerValue_isClean() async {
    _api(
      '''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}
''',
      session: '''
@CobaltChildScope()
class Session {
  const Session(@Named('session') this.api);
  final Api api;
}''',
    );

    await assertNoDiagnostics(_decorator);
  }

  void test_aNamedPromiseOfAChildScope_isClean() async {
    _api(
      '''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}
''',
      session: '''
@CobaltChildScope(provides: [CobaltProvided(Api, name: 'x')])
class Session {
  const Session();
}''',
    );

    await assertNoDiagnostics(_decorator);
  }

  void test_aNamedPromiseShadowingTheSameName_isReported() async {
    _api(
      '''
@CobaltInject(exposeAs: Api, name: 'x')
class LiveApi implements Api {}
''',
      session: '''
@CobaltChildScope(provides: [CobaltProvided(Api, name: 'x')])
class Session {
  const Session();
}''',
    );
    const source =
        '''
$cobaltImport

import 'api.dart';

@CobaltDecorates(Api, name: 'x')
class LoggedApi implements Api {
  LoggedApi(this.inner);
  final Api inner;
}
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('LoggedApi implements'),
        9,
        messageContainsAll: ["Api named 'x'"],
      ),
    ]);
  }

  void test_aNameThatIsNotALiteral_isClean() async {
    _api('''
const fake = 'fake';

@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}

@CobaltInject(exposeAs: Api, name: fake, scope: Session)
class FakeApi implements Api {}
''');

    await assertNoDiagnostics(_decorator);
  }

  void test_aGenericChildRegistration_isClean() async {
    _api('''
@CobaltInject(exposeAs: Api)
class LiveApi implements Api {}

@CobaltInject(exposeAs: Api, scope: Session, instantiations: [FakeApi<int>])
class FakeApi<T> implements Api {}
''');

    await assertNoDiagnostics(_decorator);
  }

  void test_aForeignTargetSharingANameWithAPackageClass_isClean() async {
    newFile('$testPackageLibPath/session.dart', '''
$cobaltImport

@CobaltChildScope()
class Session {
  const Session();
}

@CobaltInject(scope: Session)
class Client {}
''');
    newFile('$testPackageLibPath/module.dart', '''
$cobaltImport

import 'package:http/http.dart';

@cobaltModule
class HttpModule {
  const HttpModule();

  @cobaltInject
  Client client() => Client();
}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'package:http/http.dart';

@CobaltDecorates(Client)
class LoggedClient implements Client {
  LoggedClient(this.inner);
  final Client inner;
}
''');
  }

  void test_aPrefixedModuleTypeInAChildScope_isClean() async {
    newFile('$testPackageLibPath/client.dart', '''
$cobaltImport

import 'package:http/http.dart' as http;

@CobaltChildScope()
class Session {
  const Session();
}

@cobaltInject
class Client {}

@cobaltModule
class HttpModule {
  const HttpModule();

  @CobaltInject(scope: Session)
  http.Client client() => http.Client();
}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'client.dart';

@CobaltDecorates(Client)
class LoggedClient implements Client {
  LoggedClient(this.inner);
  final Client inner;
}
''');
  }

  void test_aPrefixedExposedTypeInAChildScope_isClean() async {
    newFile('$testPackageLibPath/client.dart', '''
$cobaltImport

import 'package:http/http.dart' as http;

@CobaltChildScope()
class Session {
  const Session();
}

@cobaltInject
class Client {}

@CobaltInject(exposeAs: http.Client, scope: Session)
class FakeClient implements http.Client {}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'client.dart';

@CobaltDecorates(Client)
class LoggedClient implements Client {
  LoggedClient(this.inner);
  final Client inner;
}
''');
  }
}
