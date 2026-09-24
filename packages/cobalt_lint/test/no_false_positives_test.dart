// `test_reflective_loader` finds tests by a `test_` prefix, which is not a
// Dart identifier name. The rule is off per file rather than through a
// `test/analysis_options.yaml`: that file had to `include` the repository
// root, and a copy of this package taken out of the tree cannot reach it.
// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/rules/bootstrap_requires_run_method.dart';
import 'package:cobalt_lint/src/rules/bootstrap_step_cannot_inject.dart';
import 'package:cobalt_lint/src/rules/dependency_cycle.dart';
import 'package:cobalt_lint/src/rules/dependency_is_not_registered.dart';
import 'package:cobalt_lint/src/rules/environment_needs_a_registration.dart';
import 'package:cobalt_lint/src/rules/init_requires_init_method.dart';
import 'package:cobalt_lint/src/rules/injectable_must_be_constructible.dart';
import 'package:cobalt_lint/src/rules/injected_field_must_be_late_final.dart';
import 'package:cobalt_lint/src/rules/injected_field_needs_an_injectable.dart';
import 'package:cobalt_lint/src/rules/lazy_registration_injected_synchronously.dart';
import 'package:cobalt_lint/src/rules/missing_injection_mixin.dart';
import 'package:cobalt_lint/src/rules/param_needs_an_injectable.dart';
import 'package:cobalt_lint/src/rules/registration_is_never_released.dart';
import 'package:cobalt_lint/src/rules/resource_is_never_closed.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(BootstrapRequiresRunMethodIsQuiet);
    defineReflectiveTests(BootstrapStepCannotInjectIsQuiet);
    defineReflectiveTests(DependencyCycleIsQuiet);
    defineReflectiveTests(DependencyIsNotRegisteredIsQuiet);
    defineReflectiveTests(EnvironmentNeedsARegistrationIsQuiet);
    defineReflectiveTests(InitRequiresInitMethodIsQuiet);
    defineReflectiveTests(InjectableMustBeConstructibleIsQuiet);
    defineReflectiveTests(InjectedFieldMustBeLateFinalIsQuiet);
    defineReflectiveTests(InjectedFieldNeedsAnInjectableIsQuiet);
    defineReflectiveTests(LazyRegistrationInjectedSynchronouslyIsQuiet);
    defineReflectiveTests(MissingInjectionMixinIsQuiet);
    defineReflectiveTests(ParamNeedsAnInjectableIsQuiet);
    defineReflectiveTests(RegistrationIsNeverReleasedIsQuiet);
    defineReflectiveTests(ResourceIsNeverClosedIsQuiet);
  });
}

/// Every rule, over a graph the build accepts.
///
/// The per-rule suites each prove their own rule stays quiet where it should.
/// None of them proves the *set* does: a rule can be silent on the four
/// declarations its own author thought of and loud on the fifth, which some
/// other rule's author wrote. That is the shape of the two false positives
/// this package has already shipped and fixed.
///
/// It answers the half of "does a clean lint mean the build will pass" that
/// can be answered. It cannot mean that — thirty build-time refusals against
/// fourteen rules, deliberately — but the reverse has to hold: nothing here
/// may report code the generator is happy with.
abstract class _QuietTest extends AnalysisRuleTest {
  AnalysisRule makeRule();

  /// One package touching every shape the generator accepts: a plain
  /// injectable, a named one, `exposeAs`, an async init with `dependsOn`, a
  /// bootstrap step, a module, a call-site value, property injection, a
  /// transient, and a class that says how it closes.
  static const _graph =
      '''
$cobaltImport
$cobaltRuntimeImport

import 'dart:async';

class Config {
  const Config();
}

@cobaltInject
class Clock {}

@CobaltInject(exposeAs: Sink)
class Console implements Sink {}

abstract interface class Sink {}

@CobaltInject(name: 'audit')
class AuditLog {
  AuditLog(this.clock);

  final Clock clock;
}

@cobaltInit
class Database {
  Future<void> init() async {}
}

@CobaltInit(dependsOn: [Database])
class SearchIndex {
  SearchIndex(this.database);

  final Database database;

  Future<void> init() async {}
}

@cobaltTransient
class Query {
  Query(this.index);

  final SearchIndex index;
}

@cobaltInject
class Editor {
  Editor(this.clock, {@cobaltParam required this.id});

  final Clock clock;
  final int id;
}

// The mixin stands in for what the generator writes; the class is only
// well-formed with it, which is what `cobalt_missing_injection_mixin` says.
mixin _\$Controller {}

@cobaltInject
class Controller with _\$Controller {
  @injected
  late final Clock clock;
}

@cobaltInject
class Watcher implements Disposable {
  late final StreamSubscription<int> subscription;

  @override
  void dispose() {}
}

@cobaltBootstrap
class BindPlatform {
  Future<void> run() async {}
}

@cobaltModule
class PlatformModule {
  const PlatformModule();

  @cobaltInject
  Config config() => const Config();
}

@cobaltLazyInit
class Archive {
  Archive(this.config);

  final Config config;

  Future<void> init() async {}
}

@cobaltLazyInit
class ArchiveIndex {
  ArchiveIndex(this.archive);

  final Archive archive;

  Future<void> init() async {}
}

@CobaltScopeRoot(name: 'app')
class AppScope {
  const AppScope();
}
''';

  @override
  void setUp() {
    stubCobaltAnnotations(this);
    stubCobaltRuntime(this);
    rule = makeRule();
    super.setUp();
  }

  void test_isQuietOnAGraphTheBuildAccepts() async {
    await assertNoDiagnostics(_graph);
  }
}

@reflectiveTest
class BootstrapRequiresRunMethodIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => BootstrapRequiresRunMethod();
}

@reflectiveTest
class BootstrapStepCannotInjectIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => BootstrapStepCannotInject();
}

@reflectiveTest
class DependencyCycleIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => DependencyCycle();
}

@reflectiveTest
class DependencyIsNotRegisteredIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => DependencyIsNotRegistered();
}

@reflectiveTest
class EnvironmentNeedsARegistrationIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => EnvironmentNeedsARegistration();
}

@reflectiveTest
class InitRequiresInitMethodIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => InitRequiresInitMethod();
}

@reflectiveTest
class InjectableMustBeConstructibleIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => InjectableMustBeConstructible();
}

@reflectiveTest
class InjectedFieldMustBeLateFinalIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => InjectedFieldMustBeLateFinal();
}

@reflectiveTest
class InjectedFieldNeedsAnInjectableIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => InjectedFieldNeedsAnInjectable();
}

@reflectiveTest
class LazyRegistrationInjectedSynchronouslyIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => LazyRegistrationInjectedSynchronously();
}

@reflectiveTest
class MissingInjectionMixinIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => MissingInjectionMixin();
}

@reflectiveTest
class ParamNeedsAnInjectableIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => ParamNeedsAnInjectable();
}

@reflectiveTest
class RegistrationIsNeverReleasedIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => RegistrationIsNeverReleased();
}

@reflectiveTest
class ResourceIsNeverClosedIsQuiet extends _QuietTest {
  @override
  AnalysisRule makeRule() => ResourceIsNeverClosed();
}
