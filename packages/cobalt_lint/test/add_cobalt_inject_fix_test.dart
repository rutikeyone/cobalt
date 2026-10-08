// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/fixes/add_cobalt_inject.dart';
import 'package:cobalt_lint/src/rules/environment_needs_a_registration.dart';
import 'package:cobalt_lint/src/rules/injected_field_needs_an_injectable.dart';
import 'package:cobalt_lint/src/rules/param_needs_an_injectable.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_support.dart';
import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddCobaltInjectForInjectedFieldTest);
    defineReflectiveTests(AddCobaltInjectForEnvironmentTest);
    defineReflectiveTests(AddCobaltInjectForParamTest);
  });
}

@reflectiveTest
class AddCobaltInjectForInjectedFieldTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = InjectedFieldNeedsAnInjectable();
    super.setUp();
  }

  void test_bareClass_isAnnotated() async {
    expect(
      await fixed('''
$cobaltImport

class Orphan {
  @injected
  late final String value;
}
''', AddCobaltInject.new),
      '''
$cobaltImport

@cobaltInject
class Orphan {
  @injected
  late final String value;
}
''',
    );
  }

  void test_docCommentAndAnnotations_stayAbove() async {
    expect(
      await fixed('''
$cobaltImport

/// Reads the orphanage.
@Deprecated('soon')
final class Orphan {
  @injected
  late final String value;
}
''', AddCobaltInject.new),
      '''
$cobaltImport

/// Reads the orphanage.
@Deprecated('soon')
@cobaltInject
final class Orphan {
  @injected
  late final String value;
}
''',
    );
  }

  void test_prefixedImport_isNotFixed() async {
    expect(
      await fixed('''
import 'package:cobalt_annotations/cobalt_annotations.dart' as cobalt;

class Orphan {
  @cobalt.injected
  late final String value;
}
''', AddCobaltInject.new),
      isNull,
    );
  }

  void test_abstractClass_isNotFixed() async {
    expect(
      await fixed('''
$cobaltImport

abstract class Orphan {
  @injected
  late final String value;
}
''', AddCobaltInject.new),
      isNull,
    );
  }
}

@reflectiveTest
class AddCobaltInjectForEnvironmentTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = EnvironmentNeedsARegistration();
    super.setUp();
  }

  void test_environment_getsARegistrationBelowIt() async {
    expect(
      await fixed('''
$cobaltImport

@CobaltEnvironment.dev
class FakeApi {}
''', AddCobaltInject.new),
      '''
$cobaltImport

@CobaltEnvironment.dev
@cobaltInject
class FakeApi {}
''',
    );
  }

  void test_hiddenConstant_isNotFixed() async {
    expect(
      await fixed('''
import 'package:cobalt_annotations/cobalt_annotations.dart' hide cobaltInject;

@CobaltEnvironment.dev
class FakeApi {}
''', AddCobaltInject.new),
      isNull,
    );
  }
}

@reflectiveTest
class AddCobaltInjectForParamTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = ParamNeedsAnInjectable();
    super.setUp();
  }

  void test_param_registersItsClass() async {
    expect(
      await fixed('''
$cobaltImport

class Orphan {
  Orphan({@cobaltParam required this.id});

  final int id;
}
''', AddCobaltInject.new),
      '''
$cobaltImport

@cobaltInject
class Orphan {
  Orphan({@cobaltParam required this.id});

  final int id;
}
''',
    );
  }
}
