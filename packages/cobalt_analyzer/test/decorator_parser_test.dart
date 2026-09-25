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
class Logger {}
''';

  group('what it reads', () {
    test('the target, the inner parameter and the dependencies', () async {
      final decorator = await parse('''
$api
@CobaltDecorates(Api)
class Wrapper implements Api {
  Wrapper(this.log, this.inner);
  final Logger log;
  final Api inner;
}
''');

      expect(decorator.type.name, 'Wrapper');
      expect(decorator.target.name, 'Api');
      expect(decorator.inner, 'inner');
      expect(decorator.constructorParameters.map((p) => p.field), [
        'log',
        'inner',
      ]);
      expect(decorator.dependencies.single.type.name, 'Logger');
      expect(decorator.order, isNull);
      expect(decorator.name, isNull);
    });

    test('name, order, @Named, a named inner and environments', () async {
      final decorator = await parse('''
$api
@CobaltDecorates(Api, name: 'primary', order: 2)
@CobaltEnvironment.dev
class Wrapper implements Api {
  Wrapper(@Named('audit') this.log, {required this.inner});
  final Logger log;
  final Api inner;
}
''');

      expect(decorator.name, 'primary');
      expect(decorator.order, 2);
      expect(decorator.environments, {'dev'});
      expect(decorator.dependencies.single.name, 'audit');
      expect(
        decorator.constructorParameters.firstWhere((p) => p.field == 'inner'),
        isA<CobaltInjectedProperty>().having((p) => p.isNamed, 'isNamed', true),
      );
    });

    test('a subclass of a concrete target decorates it', () async {
      final decorator = await parse('''
class Api {}
@CobaltDecorates(Api)
class Wrapper extends Api {
  Wrapper(this.inner);
  final Api inner;
}
''');

      expect(decorator.inner, 'inner');
    });

    test('the library parser collects it apart from registrations', () async {
      final declarations = const CobaltParser().parseLibrary(
        await libraryFrom('''
$api
@cobaltInject
class Real implements Api {}

@CobaltDecorates(Api)
class Wrapper implements Api {
  Wrapper(this.inner);
  final Api inner;
}
'''),
      );

      expect(declarations.injectables.single.type.name, 'Real');
      expect(declarations.decorators.single.type.name, 'Wrapper');
      expect(declarations.isEmpty, isFalse);
    });
  });

  group('what it refuses', () {
    test('a class that is not the type it decorates', () async {
      expect(
        () => parse('''
$api
@CobaltDecorates(Api)
class Wrapper {
  Wrapper(this.inner);
  final Api inner;
}
'''),
        rejects(contains('has to implement Api')),
      );
    });

    test('no parameter of the target type', () async {
      expect(
        () => parse('''
$api
@CobaltDecorates(Api)
class Wrapper implements Api {
  Wrapper(this.log);
  final Logger log;
}
'''),
        rejects(
          contains(
            'takes exactly one Api — the instance it wraps. It '
            'takes 0',
          ),
        ),
      );
    });

    test('two parameters of the target type', () async {
      expect(
        () => parse('''
$api
@CobaltDecorates(Api)
class Wrapper implements Api {
  Wrapper(this.a, this.b);
  final Api a;
  final Api b;
}
'''),
        rejects(contains('It takes 2')),
      );
    });

    test('a class that is also a registration', () async {
      expect(
        () => parse('''
$api
@cobaltInject
@CobaltDecorates(Api)
class Wrapper implements Api {
  Wrapper(this.inner);
  final Api inner;
}
'''),
        rejects(contains('both a decorator and a registration')),
      );
    });

    test('decorating twice', () async {
      expect(
        () => parse('''
$api
abstract interface class Other {}
@CobaltDecorates(Api)
@CobaltDecorates(Other)
class Wrapper implements Api, Other {
  Wrapper(this.inner);
  final Api inner;
}
'''),
        rejects(contains('more than once')),
      );
    });

    test('an abstract class', () async {
      expect(
        () => parse('''
$api
@CobaltDecorates(Api)
abstract class Wrapper implements Api {
  Wrapper(this.inner);
  final Api inner;
}
'''),
        rejects(contains('is abstract')),
      );
    });

    test('type parameters', () async {
      expect(
        () => parse('''
$api
@CobaltDecorates(Api)
class Wrapper<T> implements Api {
  Wrapper(this.inner);
  final Api inner;
}
'''),
        rejects(contains('declares type parameters')),
      );
    });

    test('no public generative constructor', () async {
      expect(
        () => parse('''
$api
@CobaltDecorates(Api)
class Wrapper implements Api {
  Wrapper._(this.inner);
  factory Wrapper(Api inner) => Wrapper._(inner);
  final Api inner;
}
'''),
        rejects(contains('no public generative constructor')),
      );
    });

    test('a call-site value', () async {
      expect(
        () => parse('''
$api
@CobaltDecorates(Api)
class Wrapper implements Api {
  Wrapper(this.inner, {@cobaltParam required this.id});
  final Api inner;
  final int id;
}
'''),
        rejects(contains('@CobaltParam')),
      );
    });

    test('property injection', () async {
      expect(
        () => parse('''
$api
@CobaltDecorates(Api)
class Wrapper implements Api {
  Wrapper(this.inner);
  final Api inner;
  @injected
  late final Logger log;
}
'''),
        rejects(contains('is @injected')),
      );
    });
  });
}
