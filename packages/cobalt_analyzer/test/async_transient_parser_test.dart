import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher _rejects(Object matcher) => throwsA(
  isA<CobaltParseError>().having((e) => e.message, 'message', matcher),
);

void main() {
  group('a class', () {
    const parser = CobaltInjectableParser();

    test('@cobaltTransient with @CobaltInit is an async transient', () async {
      final clazz = await classNamed('Report', '''
@cobaltTransient
@cobaltInit
class Report {
  Report();
  Future<void> init() async {}
}
''');

      final parsed = parser.parseClass(clazz).single;
      expect(parsed.lifetime, CobaltLifetime.transient);
      expect(parsed.isAsyncInit, isTrue);
      expect(parsed.isAsyncTransient, isTrue);
      expect(parsed.isAwaited, isTrue);
      expect(parsed.isLazyAsync, isFalse);
      expect(parsed.isBuiltInPhaseOne, isFalse);
    });

    test('the lifetime may be spelled out', () async {
      final clazz = await classNamed('Report', '''
@CobaltInject(lifetime: CobaltLifetime.transient)
@CobaltInit()
class Report {
  Report();
  Future<void> init() async {}
}
''');

      expect(parser.parseClass(clazz).single.isAsyncTransient, isTrue);
    });

    test('a plain @CobaltInit stays a singleton built by init()', () async {
      final clazz = await classNamed('Database', '''
@cobaltInit
class Database {
  Database();
  Future<void> init() async {}
}
''');

      final parsed = parser.parseClass(clazz).single;
      expect(parsed.lifetime, CobaltLifetime.lazySingleton);
      expect(parsed.isAsyncTransient, isFalse);
      expect(parsed.isBuiltInPhaseOne, isTrue);
    });

    test('a transient without @CobaltInit is a synchronous one', () async {
      final clazz = await classNamed('Report', '''
@cobaltTransient
class Report {
  Report();
}
''');

      final parsed = parser.parseClass(clazz).single;
      expect(parsed.isAsyncTransient, isFalse);
      expect(parsed.isAwaited, isFalse);
    });

    test('a call-site value makes it async parameterized instead', () async {
      final clazz = await classNamed('Report', '''
@cobaltTransient
@cobaltInit
class Report {
  Report(@cobaltParam this.id);
  final int id;
  Future<void> init() async {}
}
''');

      final parsed = parser.parseClass(clazz).single;
      expect(parsed.isAsyncParam, isTrue);
      expect(parsed.isAsyncTransient, isFalse);
    });

    test('lazy is refused', () async {
      final clazz = await classNamed('Report', '''
@cobaltTransient
@CobaltInit(lazy: true)
class Report {
  Report();
  Future<void> init() async {}
}
''');

      expect(
        () => parser.parseClass(clazz),
        _rejects(allOf(contains('transient'), contains('Drop lazy'))),
      );
    });

    test('dependsOn is refused', () async {
      final clazz = await classNamed('Report', '''
@cobaltInit
class Database {
  Database();
  Future<void> init() async {}
}

@cobaltTransient
@CobaltInit(dependsOn: [Database])
class Report {
  Report();
  Future<void> init() async {}
}
''');

      expect(
        () => parser.parseClass(clazz),
        _rejects(allOf(contains('transient'), contains('Drop the dependsOn'))),
      );
    });

    test('a dispose function is refused, as for any transient', () async {
      final clazz = await classNamed('Report', '''
void close(Report report) {}

@CobaltInject(lifetime: CobaltLifetime.transient, dispose: close)
@cobaltInit
class Report {
  Report();
  Future<void> init() async {}
}
''');

      expect(
        () => parser.parseClass(clazz),
        _rejects(contains('never retains a transient')),
      );
    });
  });

  group('a module member', () {
    const parser = CobaltModuleParser();

    test(
      'a transient member returning a Future is an async transient',
      () async {
        final declarations = parser.parseClass(
          await classNamed('Module', '''
class Connection {}

@cobaltModule
class Module {
  const Module();

  @cobaltTransient
  Future<Connection> connection() async => Connection();
}
'''),
        );

        final connection = declarations.single;
        expect(connection.type.name, 'Connection');
        expect(connection.lifetime, CobaltLifetime.transient);
        expect(connection.isAsyncTransient, isTrue);
        expect(connection.isBuiltInPhaseOne, isFalse);
      },
    );

    test('lazyInit on it is refused', () async {
      final clazz = await classNamed('Module', '''
class Connection {}

@cobaltModule
class Module {
  const Module();

  @CobaltInject(lifetime: CobaltLifetime.transient, lazyInit: true)
  Future<Connection> connection() async => Connection();
}
''');

      expect(
        () => parser.parseClass(clazz),
        _rejects(allOf(contains('transient'), contains('Drop lazyInit'))),
      );
    });

    test('a dispose function on it is refused', () async {
      final clazz = await classNamed('Module', '''
class Connection {}
void close(Connection connection) {}

@cobaltModule
class Module {
  const Module();

  @CobaltInject(lifetime: CobaltLifetime.transient, dispose: close)
  Future<Connection> connection() async => Connection();
}
''');

      expect(
        () => parser.parseClass(clazz),
        _rejects(contains('does not retain a transient')),
      );
    });
  });

  group('the IR', () {
    test('an async transient survives JSON', () {
      const declaration = CobaltInjectableClass(
        type: CobaltTypeRef(name: 'Report', import: 'package:a/a.dart'),
        lifetime: CobaltLifetime.transient,
        constructorParameters: [],
        properties: [],
        isAsyncInit: true,
      );

      final restored = CobaltInjectableClass.fromJson(declaration.toJson());
      expect(restored.isAsyncTransient, isTrue);
    });
  });
}
