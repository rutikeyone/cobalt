// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/fixes/add_injection_mixin.dart';
import 'package:cobalt_lint/src/rules/missing_injection_mixin.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_support.dart';
import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddInjectionMixinTest);
  });
}

@reflectiveTest
class AddInjectionMixinTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = MissingInjectionMixin();
    super.setUp();
  }

  Future<void> check(String header, String expected) async {
    String source(String header, {String part = ''}) =>
        '''
$cobaltImport$part

class Base {}

mixin Other {}

abstract interface class Api {}

@cobaltInject
$header {
  @injected
  late final String value;
}
''';

    expect(
      await fixed(source(header), AddInjectionMixin.new),
      source(expected, part: "\n\npart 'test.g.dart';"),
    );
  }

  void test_noClauses_addsAWithClause() async {
    await check('class Bloc', 'class Bloc with _\$Bloc');
  }

  void test_extends_goesAfterIt() async {
    await check(
      'class Bloc extends Base',
      'class Bloc extends Base with _\$Bloc',
    );
  }

  void test_existingWith_isAppendedTo() async {
    await check('class Bloc with Other', 'class Bloc with Other, _\$Bloc');
  }

  void test_typeParametersAndImplements_goesBetweenThem() async {
    await check(
      'class Bloc<T> implements Api',
      'class Bloc<T> with _\$Bloc<T> implements Api',
    );
  }

  void test_mixinWithoutTypeArguments_getsThem() async {
    await check(
      'class Bloc<K, V> with Other, _\$Bloc',
      'class Bloc<K, V> with Other, _\$Bloc<K, V>',
    );
  }

  void test_aPartAlreadyDeclared_isKept() async {
    const source =
        '''
$cobaltImport

part 'test.g.dart';

@cobaltInject
class Bloc {
  @injected
  late final String value;
}
''';

    expect(
      await fixed(source, AddInjectionMixin.new),
      source.replaceFirst('class Bloc', 'class Bloc with _\$Bloc'),
    );
  }

  void test_anotherPart_getsOursBesideIt() async {
    const source =
        '''
$cobaltImport

part 'test.freezed.dart';

@cobaltInject
class Bloc {
  @injected
  late final String value;
}
''';

    expect(
      await fixed(source, AddInjectionMixin.new),
      source
          .replaceFirst(
            "part 'test.freezed.dart';",
            "part 'test.freezed.dart';\n\npart 'test.g.dart';",
          )
          .replaceFirst('class Bloc', 'class Bloc with _\$Bloc'),
    );
  }

  void test_everyClause_keepsDartsOrder() async {
    await check(
      'final class Bloc extends Base with Other implements Api',
      'final class Bloc extends Base with Other, _\$Bloc implements Api',
    );
  }
}
