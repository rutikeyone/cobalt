// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/dependency_is_not_registered.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DependencyIsNotRegisteredTest);
  });
}

@reflectiveTest
class DependencyIsNotRegisteredTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = DependencyIsNotRegistered();
    super.setUp();
  }

  void test_registeredInTheSameFile_isClean() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
class Logger {}

@cobaltInject
class Api {
  Api(this.logger);
  final Logger logger;
}
''');
  }

  void test_registeredInAnotherFile_isClean() async {
    newFile('$testPackageLibPath/logger.dart', '''
$cobaltImport

@cobaltInject
class Logger {}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'logger.dart';

@cobaltInject
class Api {
  Api(this.logger);
  final Logger logger;
}
''');
  }

  void test_exposedByAnotherClass_isClean() async {
    newFile('$testPackageLibPath/notes.dart', '''
$cobaltImport

abstract interface class Notes {}

@CobaltInject(exposeAs: Notes)
class SqlNotes implements Notes {}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'notes.dart';

@cobaltInject
class Editor {
  Editor(this.notes);
  final Notes notes;
}
''');
  }

  void test_promisedByTheScopeRoot_isClean() async {
    newFile('$testPackageLibPath/app_scope.dart', '''
$cobaltImport

import 'session.dart';

@CobaltScopeRoot(name: 'app', provides: [SessionManager])
class AppScope {
  const AppScope();
}
''');
    newFile('$testPackageLibPath/session.dart', '''
class SessionManager {}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'session.dart';

@cobaltInject
class Profile {
  Profile(this.session);
  final SessionManager session;
}
''');
  }

  void test_promisedByName_isClean() async {
    newFile('$testPackageLibPath/app_scope.dart', '''
$cobaltImport

import 'audit.dart';

@CobaltScopeRoot(name: 'app', provides: [CobaltProvided(Auditor, name: 'audit')])
class AppScope {
  const AppScope();
}
''');
    newFile('$testPackageLibPath/audit.dart', '''
class Auditor {}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'audit.dart';

@cobaltInject
class Ledger {
  Ledger(this.auditor);
  final Auditor auditor;
}
''');
  }

  void test_nothingRegistersIt_isReported() async {
    newFile('$testPackageLibPath/http.dart', '''
class HttpClient {}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'http.dart';

@cobaltInject
class Api {
  Api(this.client);
  final HttpClient client;
}
''',
      [lint(103, 3)],
    );
  }

  void test_anInjectedProperty_isReported() async {
    newFile('$testPackageLibPath/http.dart', '''
class HttpClient {}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'http.dart';

@cobaltInject
class Api {
  Api();

  @injected
  late final HttpClient _client;
}
''',
      [lint(103, 3)],
    );
  }

  void test_dependsOn_isReported() async {
    newFile('$testPackageLibPath/database.dart', '''
class Database {}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'database.dart';

@CobaltInit(dependsOn: [Database])
class Index {
  Index();
  Future<void> init() async {}
}
''',
      [lint(128, 5)],
    );
  }

  void test_anUnannotatedClass_isClean() async {
    newFile('$testPackageLibPath/http.dart', '''
class HttpClient {}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'http.dart';

@cobaltInject
class Settings {}

class Api {
  Api(this.client);
  final HttpClient client;
}
''');
  }

  void test_aMalformedInjectable_isLeftToItsOwnRule() async {
    newFile('$testPackageLibPath/http.dart', '''
class HttpClient {}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'http.dart';

@cobaltInject
abstract class Api {
  Api(this.client);
  final HttpClient client;
}
''');
  }

  /// The index holds bare names, so a qualifier it cannot see never turns into
  /// a report. The build still rejects this graph — see the rule's doc for why
  /// the editor is deliberately the weaker of the two.
  void test_aNameTheRegistrationDoesNotCarry_isNotReported() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
class Logger {}

@cobaltInject
class Api {
  Api(@Named('audit') this.logger);
  final Logger logger;
}
''');
  }

  void test_providedByAModuleInAnotherFile_isClean() async {
    newFile('$testPackageLibPath/network.dart', '''
$cobaltImport

class Dio {}

@cobaltModule
class NetworkModule {
  const NetworkModule();

  @cobaltInject
  Dio dio() => Dio();
}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'network.dart';

@cobaltInject
class Api {
  Api(this.dio);
  final Dio dio;
}
''');
  }

  void test_providedAsyncByAModule_isClean() async {
    newFile('$testPackageLibPath/storage.dart', '''
$cobaltImport

class Prefs {}

@cobaltModule
class StorageModule {
  const StorageModule();

  @cobaltInject
  Future<Prefs> get prefs async => Prefs();
}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'storage.dart';

@cobaltInject
class Settings {
  Settings(this.prefs);
  final Prefs prefs;
}
''');
  }

  void test_aModuleMemberWantingSomethingUnregistered_isReported() async {
    newFile('$testPackageLibPath/http.dart', '''
class HttpClient {}
class Dio {}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'http.dart';

@cobaltModule
class NetworkModule {
  const NetworkModule();

  @cobaltInject
  Dio dio(HttpClient client) => Dio();
}
''',
      [lint(103, 13)],
    );
  }

  void test_anOptionalDependency_isClean() async {
    newFile('$testPackageLibPath/http.dart', '''
class HttpClient {}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'http.dart';

@cobaltInject
class Api {
  Api(this.client);
  final HttpClient? client;
}
''');
  }

  /// `CobaltTypeRef` compares by signature, which ignores nullability, so
  /// collecting dependencies into a set would fold these two into one entry
  /// and let declaration order decide whether the required one is checked.
  void test_aRequiredDependencyBesideAnOptionalOne_isReported() async {
    newFile('$testPackageLibPath/http.dart', '''
class HttpClient {}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'http.dart';

@cobaltInject
class Api {
  Api(this.maybe, this.required);
  final HttpClient? maybe;
  final HttpClient required;
}
''',
      [lint(103, 3)],
    );
  }

  /// The same pair the other way round: whichever is declared first, the
  /// required one still has to be seen.
  void test_aRequiredDependencyBeforeAnOptionalOne_isReported() async {
    newFile('$testPackageLibPath/http.dart', '''
class HttpClient {}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'http.dart';

@cobaltInject
class Api {
  Api(this.required, this.maybe);
  final HttpClient required;
  final HttpClient? maybe;
}
''',
      [lint(103, 3)],
    );
  }

  /// Same reason: type arguments are not part of the index, so any
  /// `Repository` registration answers for every instantiation.
  void test_anotherInstantiationOfAGeneric_isNotReported() async {
    await assertNoDiagnostics('''
$cobaltImport

class User {}
class Order {}

abstract interface class Repository<T> {}

@CobaltInject(exposeAs: Repository<User>)
class UserRepository implements Repository<User> {}

@cobaltInject
class Catalog {
  Catalog(this.orders);
  final Repository<Order> orders;
}
''');
  }

  /// Without the skip, `int` is reported as a dependency nothing registers —
  /// on every parameterized class there is.
  void test_callSiteValue_isNotADependency() async {
    await assertNoDiagnostics(r'''
import 'package:cobalt_annotations/cobalt_annotations.dart';

@cobaltInject
class Repo {
  Repo();
}

@cobaltInject
class NoteEditor {
  NoteEditor(this.repo, {@cobaltParam required this.id});

  final Repo repo;
  final int id;
}
''');
  }

  void test_aRealDependencyBesideACallSiteValue_isStillChecked() async {
    await assertDiagnostics(
      r'''
import 'package:cobalt_annotations/cobalt_annotations.dart';

@cobaltInject
class NoteEditor {
  NoteEditor(this.repo, {@cobaltParam required this.id});

  final Repo repo;
  final int id;
}

class Repo {}
''',
      [lint(82, 10)],
    );
  }

  void test_aClassRegisteredWithCobaltLazyInit_isRegistered() async {
    newFile('$testPackageLibPath/engine.dart', '''
$cobaltImport

@cobaltLazyInit
class Engine {
  Engine();
  Future<void> init() async {}
}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'engine.dart';

@cobaltLazyInit
class Search {
  Search(this.engine);
  final Engine engine;
  Future<void> init() async {}
}
''');
  }
}
