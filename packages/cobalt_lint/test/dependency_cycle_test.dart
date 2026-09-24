// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/dependency_cycle.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DependencyCycleTest);
  });
}

@reflectiveTest
class DependencyCycleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = DependencyCycle();
    super.setUp();
  }

  void test_aChainThatEnds_isClean() async {
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

  void test_aDependencyNothingRegisters_isNotAnEdge() async {
    await assertNoDiagnostics('''
$cobaltImport

@cobaltInject
class Api {
  Api(this.client);
  final HttpClient client;
}

class HttpClient {}
''');
  }

  void test_aClassThatTakesItself_isReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

@cobaltInject
class Api {
  Api(this.self);
  final Api self;
}
''',
      [lint(82, 3)],
    );
  }

  void test_twoClassesInOneFile_areBothReported() async {
    await assertDiagnostics(
      '''
$cobaltImport

@cobaltInject
class Api {
  Api(this.cache);
  final Cache cache;
}

@cobaltInject
class Cache {
  Cache(this.api);
  final Api api;
}
''',
      [lint(82, 3), lint(151, 5)],
    );
  }

  void test_aLoopThatSpansFiles_isReported() async {
    newFile('$testPackageLibPath/cache.dart', '''
$cobaltImport

import 'api.dart';

@cobaltInject
class Cache {
  Cache(this.api);
  final Api api;
}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'cache.dart';

@cobaltInject
class Api {
  Api(this.cache);
  final Cache cache;
}
''',
      [lint(104, 3)],
    );
  }

  /// Being next to a loop is not being in one.
  void test_aClassThatOnlyTouchesTheLoop_isClean() async {
    newFile('$testPackageLibPath/cache.dart', '''
$cobaltImport

import 'api.dart';

@cobaltInject
class Cache {
  Cache(this.api);
  final Api api;
}
''');

    newFile('$testPackageLibPath/api.dart', '''
$cobaltImport

import 'cache.dart';

@cobaltInject
class Api {
  Api(this.cache);
  final Cache cache;
}
''');

    await assertNoDiagnostics('''
$cobaltImport

import 'api.dart';

@cobaltInject
class Reporter {
  Reporter(this.api);
  final Api api;
}
''');
  }

  void test_aLoopThroughPropertyInjection_isReported() async {
    newFile('$testPackageLibPath/cache.dart', '''
$cobaltImport

import 'api.dart';

@cobaltInject
class Cache {
  Cache(this.api);
  final Api api;
}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'cache.dart';

@cobaltInject
class Api {
  Api();

  @injected
  late final Cache cache;
}
''',
      [lint(104, 3)],
    );
  }

  void test_aLoopThroughExposeAs_isReported() async {
    newFile('$testPackageLibPath/notes.dart', '''
$cobaltImport

import 'editor.dart';

abstract interface class Notes {}

@CobaltInject(exposeAs: Notes)
class SqlNotes implements Notes {
  SqlNotes(this.editor);
  final Editor editor;
}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'notes.dart';

@cobaltInject
class Editor {
  Editor(this.notes);
  final Notes notes;
}
''',
      [lint(104, 6)],
    );
  }

  void test_aLoopThroughDependsOn_isReported() async {
    newFile('$testPackageLibPath/index.dart', '''
$cobaltImport

import 'db.dart';

@CobaltInit(dependsOn: [Database])
class SearchIndex {
  Future<void> init() async {}
}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'index.dart';

@CobaltInit(dependsOn: [SearchIndex])
class Database {
  Future<void> init() async {}
}
''',
      [lint(128, 8)],
    );
  }

  void test_aLoopThroughAnOptionalDependency_isReported() async {
    newFile('$testPackageLibPath/cache.dart', '''
$cobaltImport

import 'api.dart';

@cobaltInject
class Cache {
  Cache(this.api);
  final Api? api;
}
''');

    await assertDiagnostics(
      '''
$cobaltImport

import 'cache.dart';

@cobaltInject
class Api {
  Api(this.cache);
  final Cache cache;
}
''',
      [lint(104, 3)],
    );
  }

  /// Two classes of the same name are two registrations the build accepts, and
  /// fusing them by name is how a graph with no loop grows one.
  /// The collision the class-declaration count cannot see: the registered
  /// `Channel` is a module member's return type, and the *other* `Channel` is
  /// an unregistered class. One declaration claims the name, so the widened
  /// ambiguity check leaves the node in the graph.
  void test_moduleMemberCollidesWithAnUnregisteredClass() async {
    newFile('$testPackageLibPath/vendor.dart', '''
class Channel {}
''');

    newFile('$testPackageLibPath/platform_module.dart', '''
$cobaltImport

import 'courier.dart';

@cobaltModule
class PlatformModule {
  const PlatformModule();

  @cobaltInject
  Channel channel(Courier courier) => Channel();
}
''');

    await assertDiagnostics('''
$cobaltImport

import 'vendor.dart';

@cobaltInject
class Courier {
  Courier(this.channel);
  final Channel channel;
}
''', []);
  }

  /// The same collision with only one side registered.
  ///
  /// `Api` takes the vendored `Clock`; the registered `Clock` takes `Api`.
  /// Two types, no loop — but one bare name, and the index is built from
  /// bare names. Reported as a cycle until 2026-09-04.
  void test_oneNameOneRegistration_staysSilent() async {
    newFile('$testPackageLibPath/vendor.dart', '''
class Clock {}
''');

    newFile('$testPackageLibPath/registered_clock.dart', '''
$cobaltImport

import 'api.dart';

@cobaltInject
class Clock {
  Clock(this.api);
  final Api api;
}
''');

    await assertDiagnostics('''
$cobaltImport

import 'vendor.dart';

@cobaltInject
class Api {
  Api(this.clock);
  final Clock clock;
}
''', []);
  }

  void test_oneNameTwoLibraries_staysSilent() async {
    newFile('$testPackageLibPath/plain.dart', '''
$cobaltImport

@cobaltInject
class Clock {}
''');

    newFile('$testPackageLibPath/ticking.dart', '''
$cobaltImport

import 'api.dart';

@cobaltInject
class Clock {
  Clock(this.api);
  final Api api;
}
''');

    await assertDiagnostics('''
$cobaltImport

import 'plain.dart';

@cobaltInject
class Api {
  Api(this.clock);
  final Clock clock;
}
''', []);
  }
}
