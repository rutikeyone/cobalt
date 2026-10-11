import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher failsWith(String text) => throwsA(
  isA<CobaltParseError>().having((e) => e.message, 'message', contains(text)),
);

void main() {
  const parser = CobaltChildScopeParser();
  const injectables = CobaltInjectableParser();
  const modules = CobaltModuleParser();

  group('a @CobaltChildScope marker', () {
    test('without a constructor holds no values', () async {
      final clazz = await classNamed('Screen', '''
@CobaltChildScope()
class Screen {}
''');

      final scope = parser.parseClass(clazz);

      expect(scope.type.name, 'Screen');
      expect(scope.builderName, 'ScreenScope');
      expect(scope.parent, isNull);
      expect(scope.values, isEmpty);
    });

    test('registers each constructor parameter as a value', () async {
      final clazz = await classNamed('Session', '''
class SessionUser {}
class Token {}

@CobaltChildScope()
class Session {
  const Session(this.user, {required this.token, @Named('label') required this.label});
  final SessionUser user;
  final Token token;
  final String label;
}
''');

      final values = parser.parseClass(clazz).values;

      expect(values.map((v) => v.field), ['user', 'token', 'label']);
      expect(values.map((v) => v.type.name), [
        'SessionUser',
        'Token',
        'String',
      ]);
      expect(values.map((v) => v.isNamed), [false, true, true]);
      expect(values.map((v) => v.name), [null, null, 'label']);
    });

    test('reads @Named from the field too', () async {
      final clazz = await classNamed('Session', '''
@CobaltChildScope()
class Session {
  const Session(this.label);
  @Named('label')
  final String label;
}
''');

      expect(parser.parseClass(clazz).values.single.name, 'label');
    });

    test('names its parent and what it is promised', () async {
      final library = await libraryFrom('''
class Draft {}

@CobaltChildScope()
class Session {}

@CobaltChildScope(parent: Session, provides: [Draft])
class Editor {}
''');
      final clazz = library.classes.firstWhere((c) => c.name == 'Editor');

      final scope = parser.parseClass(clazz);

      expect(scope.parent?.name, 'Session');
      expect(scope.provides.single.type.name, 'Draft');
    });

    test('a name ending in Scope is refused', () async {
      final clazz = await classNamed('SessionScope', '''
@CobaltChildScope()
class SessionScope {}
''');

      expect(
        () => parser.parseClass(clazz),
        failsWith('would be SessionScopeScope. Call the marker Session.'),
      );
    });

    test('a parameter that is not this.field is refused', () async {
      final clazz = await classNamed('Session', '''
@CobaltChildScope()
class Session {
  Session(String id) : label = id;
  final String label;
}
''');

      expect(
        () => parser.parseClass(clazz),
        failsWith('is not an initializing formal'),
      );
    });

    test('an optional parameter is refused', () async {
      final clazz = await classNamed('Session', '''
@CobaltChildScope()
class Session {
  const Session({this.label = 'x'});
  final String label;
}
''');

      expect(() => parser.parseClass(clazz), failsWith('is optional'));
    });

    test('a nullable parameter is refused', () async {
      final clazz = await classNamed('Session', '''
@CobaltChildScope()
class Session {
  const Session(this.label);
  final String? label;
}
''');

      expect(() => parser.parseClass(clazz), failsWith('is nullable'));
    });

    test('a parent that is not a marker is refused', () async {
      final clazz = await classNamed('Editor', '''
class Session {}

@CobaltChildScope(parent: Session)
class Editor {}
''');

      expect(
        () => parser.parseClass(clazz),
        failsWith('which is not a @CobaltChildScope marker'),
      );
    });
  });

  group('scope: on a registration', () {
    test('a class names the marker it is registered under', () async {
      final clazz = await classNamed('Draft', '''
@CobaltChildScope()
class Session {}

@CobaltInject(scope: Session)
class Draft {}
''');

      expect(injectables.parseClass(clazz).single.scope?.name, 'Session');
    });

    test('an @CobaltInit class takes it too', () async {
      final clazz = await classNamed('Sync', '''
@CobaltChildScope()
class Session {}

@CobaltInit(scope: Session)
class Sync {
  Future<void> init() async {}
}
''');

      expect(injectables.parseClass(clazz).single.scope?.name, 'Session');
    });

    test('left out, the registration is the root\'s', () async {
      final clazz = await classNamed('Draft', '''
@cobaltInject
class Draft {}
''');

      expect(injectables.parseClass(clazz).single.scope, isNull);
    });

    test('a module member names it on its annotation', () async {
      final clazz = await classNamed('SessionModule', '''
class Client {}

@CobaltChildScope()
class Session {}

@cobaltModule
class SessionModule {
  const SessionModule();

  @CobaltInject(scope: Session)
  Client get client => Client();
}
''');

      expect(modules.parseClass(clazz).single.scope?.name, 'Session');
    });

    test('a scope that is not a marker is refused', () async {
      final clazz = await classNamed('Draft', '''
class Session {}

@CobaltInject(scope: Session)
class Draft {}
''');

      expect(
        () => injectables.parseClass(clazz),
        failsWith('which is not a @CobaltChildScope marker'),
      );
    });
  });

  test('the IR keeps scope and child scopes through JSON', () async {
    final library = await libraryFrom('''
class SessionUser {}

@CobaltChildScope(provides: [SessionUser])
class Session {
  const Session(this.id);
  final String id;
}

@CobaltInject(scope: Session)
class Draft {}
''');

    final parsed = const CobaltParser().parseLibrary(library);
    final decoded = CobaltLibraryDeclarations.fromJson(parsed.toJson());

    expect(decoded.injectables.single.scope?.name, 'Session');
    final scope = decoded.childScopes.single;
    expect(scope.type.name, 'Session');
    expect(scope.values.single.field, 'id');
    expect(scope.provides.single.type.name, 'SessionUser');
  });
}
