import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  const parser = CobaltInjectableParser();

  group('a generic class', () {
    Matcher rejects(Object message) => throwsA(
      isA<CobaltParseError>().having(
        (error) => error.message,
        'message',
        message,
      ),
    );

    test('naming no instantiation is rejected with a hint', () async {
      final clazz = await classNamed('Cache', '''
@cobaltInject
class Cache<T> {
  Cache();
}
''');

      expect(
        () => parser.parseClass(clazz),
        rejects(
          allOf(
            contains('type parameters <T>'),
            contains('no single instantiation'),
            contains('@CobaltInject(instantiations: [Cache<Note>])'),
            contains('concrete subtype'),
          ),
        ),
      );
    });

    test(
      'instantiations on a class without type parameters are rejected',
      () async {
        final clazz = await classNamed('Cache', '''
@CobaltInject(instantiations: [Cache])
class Cache {
  Cache();
}
''');

        expect(
          () => parser.parseClass(clazz),
          rejects(contains('declares no type parameters')),
        );
      },
    );

    test('each instantiation is one registration with its own types', () async {
      final clazz = await classNamed('Cache', '''
class Note {}
class Tag {}
class Store<T> {}

@CobaltInject(instantiations: [Cache<Note>, Cache<Tag>])
class Cache<T> {
  Cache(this.store, {@Named('fast') required this.backup});
  final Store<T> store;
  final Store<T> backup;
}
''');

      final parsed = parser.parseClass(clazz);

      expect(parsed.map((each) => '${each.type}'), [
        'Cache<Note>',
        'Cache<Tag>',
      ]);
      expect(parsed.map((each) => each.label), ['Cache<Note>', 'Cache<Tag>']);
      expect(parsed.first.type.typeArguments.single.import, isNotNull);
      expect(
        parsed.map(
          (each) => [for (final p in each.constructorParameters) '${p.type}'],
        ),
        [
          ['Store<Note>', 'Store<Note>'],
          ['Store<Tag>', 'Store<Tag>'],
        ],
      );
      expect(parsed.first.constructorParameters.last.name, 'fast');
      expect(parsed.first.constructorParameters.last.isNamed, isTrue);
    });

    test('the annotation applies to every instantiation', () async {
      final clazz = await classNamed('Cache', '''
class Note {}
class Tag {}
class Store<T> {}

Future<void> closeCache(Object cache) async {}

@CobaltEnvironment('prod')
@CobaltInject(
  name: 'local',
  lifetime: CobaltLifetime.singleton,
  dispose: closeCache,
  instantiations: [Cache<Note>, Cache<Tag>],
)
class Cache<T> {
  Cache(this.store);
  final Store<T> store;
}
''');

      final parsed = parser.parseClass(clazz);

      expect(parsed, hasLength(2));
      for (final each in parsed) {
        expect(each.name, 'local');
        expect(each.lifetime, CobaltLifetime.singleton);
        expect(each.dispose!.name, 'closeCache');
        expect(each.environments, {'prod'});
      }
    });

    test('dependsOn applies to every instantiation', () async {
      final clazz = await classNamed('Loader', '''
class Note {}
class Tag {}
class Store<T> {}
class Database {}

@CobaltInject(instantiations: [Loader<Note>, Loader<Tag>])
@CobaltInit(dependsOn: [Database])
class Loader<T> {
  Loader(this.store);
  final Store<T> store;
  Future<void> init() async {}
}
''');

      final parsed = parser.parseClass(clazz);

      expect(parsed, hasLength(2));
      for (final each in parsed) {
        expect(each.isAsyncInit, isTrue);
        expect(each.dependsOn.single.name, 'Database');
      }
    });

    test('@CobaltParam applies to every instantiation', () async {
      final clazz = await classNamed('Page', '''
class Note {}
class Tag {}
class Store<T> {}

@CobaltInject(
  lifetime: CobaltLifetime.transient,
  instantiations: [Page<Note>, Page<Tag>],
)
class Page<T> {
  Page(this.store, {@cobaltParam required this.items});
  final Store<T> store;
  final List<T> items;
}
''');

      final parsed = parser.parseClass(clazz);

      expect(parsed.map((each) => '${each.callSiteValues.single.type}'), [
        'List<Note>',
        'List<Tag>',
      ]);
    });

    test('a raw instantiation reads as dynamic and is rejected', () async {
      final clazz = await classNamed('Cache', '''
@CobaltInject(instantiations: [Cache])
class Cache<T> {
  Cache();
}
''');

      expect(
        () => parser.parseClass(clazz),
        rejects(allOf(contains('dynamic'), contains('spell out'))),
      );
    });

    test('Never as a type argument is rejected', () async {
      final clazz = await classNamed('Cache', '''
@CobaltInject(instantiations: [Cache<Never>])
class Cache<T> {
  Cache();
}
''');

      expect(
        () => parser.parseClass(clazz),
        rejects(contains('Never is not a type argument')),
      );
    });

    test('an entry naming another class is rejected', () async {
      final clazz = await classNamed('Cache', '''
class Note {}
class Other<T> {}

@CobaltInject(instantiations: [Other<Note>])
class Cache<T> {
  Cache();
}
''');

      expect(
        () => parser.parseClass(clazz),
        rejects(contains('has to be Cache itself')),
      );
    });

    test('a duplicate instantiation is rejected', () async {
      final clazz = await classNamed('Cache', '''
class Note {}
typedef NoteCache = Cache<Note>;

@CobaltInject(instantiations: [Cache<Note>, NoteCache])
class Cache<T> {
  Cache();
}
''');

      expect(
        () => parser.parseClass(clazz),
        rejects(contains('Cache<Note> twice')),
      );
    });

    test('exposeAs together with instantiations is rejected', () async {
      final clazz = await classNamed('Cache', '''
class Note {}
abstract interface class Store {}

@CobaltInject(exposeAs: Store, instantiations: [Cache<Note>])
class Cache<T> implements Store {
  Cache();
}
''');

      expect(
        () => parser.parseClass(clazz),
        rejects(contains('also names exposeAs')),
      );
    });

    test('an @injected field is rejected', () async {
      final clazz = await classNamed('Cache', '''
class Note {}
class Clock {}

@CobaltInject(instantiations: [Cache<Note>])
class Cache<T> {
  Cache();

  @injected
  late final Clock clock;
}
''');

      expect(
        () => parser.parseClass(clazz),
        rejects(
          allOf(contains('@injected field clock'), contains('constructor')),
        ),
      );
    });
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

    final parsed = parser.parseClass(clazz).single;

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

    final parsed = parser.parseClass(clazz).single;
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

      final dispose = parser.parseClass(clazz).single.dispose!;

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

      final dispose = parser.parseClass(clazz).single.dispose!;

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
