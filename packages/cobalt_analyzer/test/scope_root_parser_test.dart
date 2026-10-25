import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  const parser = CobaltScopeRootParser();

  test('a root that promises nothing provides nothing', () async {
    final clazz = await classNamed('AppScope', '''
@CobaltScopeRoot(name: 'app')
class AppScope {
  const AppScope();
}
''');

    expect(parser.parseClass(clazz).provides, isEmpty);
  });

  test('a bare type is read as an unnamed registration', () async {
    final clazz = await classNamed('AppScope', '''
class SessionManager {}

@CobaltScopeRoot(name: 'app', provides: [SessionManager])
class AppScope {
  const AppScope();
}
''');

    final provided = parser.parseClass(clazz).provides.single;

    expect(provided.type.name, 'SessionManager');
    expect(provided.name, isNull);
  });

  test('CobaltProvided carries the qualifier', () async {
    final clazz = await classNamed('AppScope', '''
class Logger {}

@CobaltScopeRoot(name: 'app', provides: [CobaltProvided(Logger, name: 'audit')])
class AppScope {
  const AppScope();
}
''');

    final provided = parser.parseClass(clazz).provides.single;

    expect(provided.type.name, 'Logger');
    expect(provided.name, 'audit');
  });

  test('type arguments are kept, since they are part of the key', () async {
    final clazz = await classNamed('AppScope', '''
class User {}
class Repository<T> {}

@CobaltScopeRoot(name: 'app', provides: [Repository<User>])
class AppScope {
  const AppScope();
}
''');

    final provided = parser.parseClass(clazz).provides.single;

    expect(provided.type.name, 'Repository');
    expect(provided.type.typeArguments.single.name, 'User');
  });

  test(
    'something that is neither a type nor CobaltProvided is rejected',
    () async {
      final clazz = await classNamed('AppScope', '''
@CobaltScopeRoot(name: 'app', provides: ['SessionManager'])
class AppScope {
  const AppScope();
}
''');

      expect(
        () => parser.parseClass(clazz),
        throwsA(
          isA<CobaltParseError>().having(
            (e) => e.message,
            'message',
            contains('neither a type nor a CobaltProvided'),
          ),
        ),
      );
    },
  );
}
