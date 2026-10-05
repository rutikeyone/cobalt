import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  const parser = CobaltInjectableParser();

  test('a class with type parameters is rejected', () async {
    final clazz = await classNamed('Cache', '''
@cobaltInject
class Cache<T> {
  Cache();
}
''');

    expect(
      () => parser.parseClass(clazz),
      throwsA(
        isA<CobaltParseError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('type parameters <T>'),
            contains('no single instantiation'),
          ),
        ),
      ),
    );
  });

  test('a class with no public generative constructor is rejected', () async {
    final clazz = await classNamed('Cache', '''
@cobaltInject
class Cache {
  Cache._();
  factory Cache.create() => Cache._();
}
''');

    expect(
      () => parser.parseClass(clazz),
      throwsA(
        isA<CobaltParseError>().having(
          (error) => error.message,
          'message',
          contains('no public generative constructor'),
        ),
      ),
    );
  });

  test('exposeAs is read from the annotation', () async {
    final clazz = await classNamed('LiveApiClient', '''
abstract interface class ApiClient {}

@CobaltInject(exposeAs: ApiClient)
class LiveApiClient implements ApiClient {
  LiveApiClient();
}
''');

    final parsed = parser.parseClass(clazz);

    expect(parsed.exposeAs!.name, 'ApiClient');
  });

  test('a generic dependency keeps its type arguments', () async {
    final clazz = await classNamed('Catalog', '''
abstract interface class Repository<T> {}

class User {}

@cobaltInject
class Catalog {
  Catalog(this.users);
  final Repository<User> users;
}
''');

    final parsed = parser.parseClass(clazz);
    final dependency = parsed.constructorParameters.single.type;

    expect(dependency.name, 'Repository');
    expect(dependency.typeArguments.single.name, 'User');
    expect(dependency.toString(), 'Repository<User>');
  });

  group('dispose', () {
    test('a class names the function that closes it', () async {
      final clazz = await classNamed('Ticker', '''
Future<void> closeTicker(Ticker ticker) async {}

@CobaltInject(dispose: closeTicker)
class Ticker {
  Ticker();
}
''');

      final dispose = parser.parseClass(clazz).dispose!;

      expect(dispose.name, 'closeTicker');
      expect(dispose.owner, isNull);
    });

    test('a static method is named with the class that owns it', () async {
      final clazz = await classNamed('Ticker', '''
class Tickers {
  static Future<void> close(Ticker ticker) async {}
}

@CobaltInject(dispose: Tickers.close)
class Ticker {
  Ticker();
}
''');

      final dispose = parser.parseClass(clazz).dispose!;

      expect(dispose.name, 'close');
      expect(dispose.owner, 'Tickers');
    });

    test('a transient is refused, since the scope never holds one', () async {
      final clazz = await classNamed('Ticker', '''
Future<void> closeTicker(Ticker ticker) async {}

@CobaltInject(lifetime: CobaltLifetime.transient, dispose: closeTicker)
class Ticker {
  Ticker();
}
''');

      expect(
        () => parser.parseClass(clazz),
        throwsA(
          isA<CobaltParseError>().having(
            (error) => error.message,
            'message',
            allOf(contains('never retains a transient'), contains('lifetime')),
          ),
        ),
      );
    });

    test(
      'a parameterized registration is refused for the same reason',
      () async {
        final clazz = await classNamed('Ticket', '''
Future<void> closeTicket(Ticket ticket) async {}

@CobaltInject(dispose: closeTicket)
class Ticket {
  Ticket({@cobaltParam required this.id});
  final int id;
}
''');

        expect(
          () => parser.parseClass(clazz),
          throwsA(
            isA<CobaltParseError>().having(
              (error) => error.message,
              'message',
              contains('never retains a parameterized registration'),
            ),
          ),
        );
      },
    );
  });

  group('async init', () {
    test('@CobaltInit with no init() method is refused', () async {
      final clazz = await classNamed('Cache', '''
@CobaltInit()
class Cache {
  Cache();
}
''');

      expect(
        () => parser.parseClass(clazz),
        throwsA(
          isA<CobaltParseError>().having(
            (error) => error.message,
            'message',
            allOf(contains('@CobaltInit'), contains("'Future<void> init()'")),
          ),
        ),
      );
    });

    test('an init() inherited from a supertype counts', () async {
      final clazz = await classNamed('Cache', '''
abstract class Base {
  Future<void> init() async {}
}

@CobaltInit()
class Cache extends Base {
  Cache();
}
''');

      expect(() => parser.parseClass(clazz), returnsNormally);
    });
  });
}
