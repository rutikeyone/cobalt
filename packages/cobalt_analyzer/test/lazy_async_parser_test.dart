import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher _rejects(Object matcher) => throwsA(
  isA<CobaltParseError>().having((e) => e.message, 'message', matcher),
);

void main() {
  group('a class', () {
    const parser = CobaltInjectableParser();

    test('@CobaltInit(lazy: true) is lazy and still async', () async {
      final clazz = await classNamed('SearchEngine', '''
@CobaltInit(lazy: true)
class SearchEngine {
  SearchEngine();
  Future<void> init() async {}
}
''');

      final parsed = parser.parseClass(clazz);
      expect(parsed.isLazyAsync, isTrue);
      expect(parsed.isAsyncInit, isTrue);
    });

    test('cobaltLazyInit is the same thing', () async {
      final clazz = await classNamed('SearchEngine', '''
@cobaltLazyInit
class SearchEngine {
  SearchEngine();
  Future<void> init() async {}
}
''');

      expect(parser.parseClass(clazz).isLazyAsync, isTrue);
    });

    test('a plain @CobaltInit is not lazy', () async {
      final clazz = await classNamed('Database', '''
@cobaltInit
class Database {
  Database();
  Future<void> init() async {}
}
''');

      expect(parser.parseClass(clazz).isLazyAsync, isFalse);
    });

    test('lazy with dependsOn is refused', () async {
      final clazz = await classNamed('SearchEngine', '''
@cobaltInit
class Database {
  Database();
  Future<void> init() async {}
}

@CobaltInit(lazy: true, dependsOn: [Database])
class SearchEngine {
  SearchEngine();
  Future<void> init() async {}
}
''');

      expect(
        () => parser.parseClass(clazz),
        _rejects(allOf(contains('lazy: true'), contains('Drop the dependsOn'))),
      );
    });

    test('lazyInit on a class is refused with the class form named', () async {
      final clazz = await classNamed('SearchEngine', '''
@CobaltInject(lazyInit: true)
class SearchEngine {
  SearchEngine();
}
''');

      expect(
        () => parser.parseClass(clazz),
        _rejects(contains('@CobaltInit(lazy: true)')),
      );
    });
  });

  group('a module member', () {
    const parser = CobaltModuleParser();

    test('lazyInit on a Future member is lazy', () async {
      final declarations = parser.parseClass(
        await classNamed('Module', '''
class SearchEngine {}

@cobaltModule
class Module {
  const Module();

  @CobaltInject(lazyInit: true)
  Future<SearchEngine> engine() async => SearchEngine();
}
'''),
      );

      expect(declarations.single.isLazyAsync, isTrue);
      expect(declarations.single.isAsyncInit, isTrue);
    });

    test('lazyInit on a synchronous member is refused', () async {
      final clazz = await classNamed('Module', '''
class Clock {}

@cobaltModule
class Module {
  const Module();

  @CobaltInject(lazyInit: true)
  Clock clock() => Clock();
}
''');

      expect(
        () => parser.parseClass(clazz),
        _rejects(contains('does not return a Future')),
      );
    });
  });

  group('the IR', () {
    test('keeps isLazyAsync through JSON', () {
      const declaration = CobaltInjectableClass(
        type: CobaltTypeRef(name: 'SearchEngine', import: 'package:a/a.dart'),
        lifetime: CobaltLifetime.lazySingleton,
        constructorParameters: [],
        properties: [],
        isAsyncInit: true,
        isLazyAsync: true,
      );

      final read = CobaltInjectableClass.fromJson(declaration.toJson());
      expect(read.isLazyAsync, isTrue);
    });

    test('reads IR written before the flag existed as not lazy', () {
      final json = const CobaltInjectableClass(
        type: CobaltTypeRef(name: 'Old', import: 'package:a/a.dart'),
        lifetime: CobaltLifetime.lazySingleton,
        constructorParameters: [],
        properties: [],
      ).toJson()..remove('isLazyAsync');

      expect(CobaltInjectableClass.fromJson(json).isLazyAsync, isFalse);
    });
  });
}
