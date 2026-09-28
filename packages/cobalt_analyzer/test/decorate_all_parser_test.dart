import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher rejects(Object matcher) => throwsA(
  isA<CobaltParseError>().having((e) => e.message, 'message', matcher),
);

void main() {
  const parser = CobaltDecoratorParser();

  Future<CobaltDecoratorClass> parse(String source) async =>
      parser.parseClass(await classNamed('Wrapper', source));

  const api = '''
abstract interface class Api {}
''';

  test('allNames is read', () async {
    final decorator = await parse('''
$api
@CobaltDecorates(Api, allNames: true, order: 1)
class Wrapper implements Api {
  Wrapper(this.inner);
  final Api inner;
}
''');

    expect(decorator.allNames, isTrue);
    expect(decorator.name, isNull);
    expect(decorator.order, 1);
  });

  test('it is off unless asked for', () async {
    final decorator = await parse('''
$api
@CobaltDecorates(Api)
class Wrapper implements Api {
  Wrapper(this.inner);
  final Api inner;
}
''');

    expect(decorator.allNames, isFalse);
  });

  test('together with a name it is refused', () async {
    expect(
      () => parse('''
$api
@CobaltDecorates(Api, name: 'auth', allNames: true)
class Wrapper implements Api {
  Wrapper(this.inner);
  final Api inner;
}
'''),
      rejects(allOf(contains("'auth'"), contains('allNames'))),
    );
  });

  test('the IR keeps it, and reads IR written before it as off', () {
    const decorator = CobaltDecoratorClass(
      type: CobaltTypeRef(name: 'Wrapper', import: 'package:a/a.dart'),
      target: CobaltTypeRef(name: 'Api', import: 'package:a/a.dart'),
      inner: 'inner',
      constructorParameters: [],
      allNames: true,
    );

    expect(CobaltDecoratorClass.fromJson(decorator.toJson()).allNames, isTrue);
    expect(
      CobaltDecoratorClass.fromJson(
        decorator.toJson()..remove('allNames'),
      ).allNames,
      isFalse,
    );
  });
}
