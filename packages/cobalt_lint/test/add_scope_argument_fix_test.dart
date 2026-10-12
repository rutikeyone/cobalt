// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/fixes/add_scope_argument.dart';
import 'package:cobalt_lint/src/rules/dependency_is_not_registered.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_support.dart';
import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddScopeArgumentTest);
  });
}

@reflectiveTest
class AddScopeArgumentTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = DependencyIsNotRegistered();
    super.setUp();
  }

  void _scopes() => newFile('$testPackageLibPath/session.dart', '''
$cobaltImport

class SessionUser {}
class Token {}

@CobaltChildScope()
class Session {
  const Session(this.user);
  final SessionUser user;
}

@CobaltChildScope()
class Other {
  const Other(this.token);
  final Token token;
}

@CobaltChildScope()
class Again {
  const Again(this.token);
  final Token token;
}
''');

  String _class(String annotation, String type) =>
      '''
$cobaltImport

import 'session.dart';

$annotation
class Audit {
  Audit(this.value);
  final $type value;
}
''';

  Future<void> check(
    String before,
    String? after, {
    String type = 'SessionUser',
  }) async {
    _scopes();
    expect(
      await fixed(_class(before, type), AddScopeArgument.new),
      after == null ? isNull : _class(after, type),
    );
  }

  void test_aConstantBecomesTheClassAnnotation() =>
      check('@cobaltInject', '@CobaltInject(scope: Session)');

  void test_aLifetimeIsKept() => check(
    '@CobaltInject(lifetime: CobaltLifetime.singleton)',
    '@CobaltInject(lifetime: CobaltLifetime.singleton, scope: Session)',
  );

  void test_anAnnotationWithArgumentsGetsOneMore() => check(
    "@CobaltInject(name: 'audit')",
    "@CobaltInject(name: 'audit', scope: Session)",
  );

  void test_anEmptyArgumentListGetsTheArgument() =>
      check('@CobaltInject()', '@CobaltInject(scope: Session)');

  void test_anInitClassKeepsInit() async {
    _scopes();
    String source(String annotation) =>
        '''
$cobaltImport

import 'session.dart';

$annotation
class Audit {
  Audit(this.user);
  final SessionUser user;

  Future<void> init() async {}
}
''';

    expect(
      await fixed(source('@cobaltLazyInit'), AddScopeArgument.new),
      source('@CobaltInit(lazy: true, scope: Session)'),
    );
  }

  void test_twoScopesRegisteringIt_isNotGuessed() =>
      check('@cobaltInject', null, type: 'Token');
}
