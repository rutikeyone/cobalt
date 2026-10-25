import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher failsWith(Object matcher) => throwsA(
  isA<CobaltGenerationError>().having((e) => e.message, 'message', matcher),
);

CobaltInjectedProperty value(
  String field,
  String type, {
  bool isNamed = false,
  String? name,
}) => CobaltInjectedProperty(
  field: field,
  type: ref(type),
  isNamed: isNamed,
  name: name,
);

void main() {
  group('a child scope', () {
    test('gets a builder named after its marker', () {
      final source = generate(
        [
          declare('Clock'),
          declare('Draft', constructor: [dep('Clock')], scope: 'Session'),
        ],
        childScopes: [childScope('Session')],
      );

      final session = classOf(source, 'SessionScope');
      expect(
        session,
        contains(
          'final class SessionScope extends _i573.CobaltChildScopeBuilder',
        ),
      );
      expect(session, contains('const SessionScope();'));
      expect(
        session,
        contains(
          'scope.registerLazySingleton<_i137.Draft>(const _DraftFactory());',
        ),
      );
      expect(classOf(source, r'CobaltRoot'), isNot(contains('Draft')));
      expect(classOf(source, r'CobaltRoot'), contains('Clock'));
    });

    test('registers the values of its marker and takes them as the marker '
        'does', () {
      final source = generate(
        [
          declare(
            'ActivityLog',
            constructor: [
              dep('User'),
              dep('String', name: 'label'),
            ],
            scope: 'Session',
          ),
        ],
        childScopes: [
          childScope(
            'Session',
            values: [
              value('user', 'User'),
              value('label', 'String', isNamed: true, name: 'label'),
            ],
          ),
        ],
      );

      final session = classOf(source, 'SessionScope');
      expect(
        session,
        contains('const SessionScope(this.user, {required this.label});'),
      );
      expect(session, contains('final _i137.User user;'));
      expect(session, contains('scope.registerSingleton<_i137.User>(user);'));
      expect(
        session,
        contains(
          "scope.registerSingleton<_i137.String>(label, name: 'label');",
        ),
      );
    });

    test('promises what it is told someone else registers', () {
      final source = generate(
        [
          declare('Draft', constructor: [dep('Editor')], scope: 'Session'),
        ],
        childScopes: [
          childScope('Session', provides: [provided('Editor')]),
        ],
      );

      expect(
        classOf(source, 'SessionScope'),
        contains('scope.promise<_i137.Editor>();'),
      );
    });

    test('orders its registrations by what they inject', () {
      final source = generate(
        [
          declare('Sync', constructor: [dep('Queue')], scope: 'Session'),
          declare('Queue', scope: 'Session'),
        ],
        childScopes: [childScope('Session')],
      );

      final session = classOf(source, 'SessionScope');
      expect(
        session.indexOf('Queue>(const _QueueFactory())'),
        lessThan(session.indexOf('Sync>(const _SyncFactory())')),
      );
    });

    test('takes an environment when its registrations name one', () {
      final source = generate(
        [
          declare('Draft', scope: 'Session', environments: {'prod'}),
        ],
        childScopes: [childScope('Session')],
      );

      final session = classOf(source, 'SessionScope');
      expect(session, contains('const SessionScope({this.environment});'));
      expect(session, contains('CobaltEnvironment? environment;'));
      expect(
        session,
        contains(
          'final environment =\n'
          '        this.environment ??\n'
          '        scope.environment ??',
        ),
      );
      expect(session, contains('scope.useEnvironment(environment);'));
      expect(session, contains("environment.matches(const <String>{'prod'})"));
    });

    test('makes the root take the environment it passes down', () {
      final source = generate(
        [
          declare('Clock'),
          declare('Draft', scope: 'Session', environments: {'prod'}),
        ],
        childScopes: [childScope('Session')],
      );

      final root = classOf(source, 'CobaltRoot');
      expect(root, contains('this.environment ='));
      expect(root, contains('scope.useEnvironment(environment);'));
      expect(source, contains('CobaltEnvironment environment ='));
      expect(source, contains('CobaltRoot(environment: environment)'));
    });

    test('compares by the values of its marker', () {
      final source = generate(
        const [],
        childScopes: [
          childScope(
            'Session',
            values: [value('user', 'User'), value('token', 'Token')],
          ),
        ],
      );

      final session = classOf(source, 'SessionScope');
      expect(
        session,
        contains(
          'other is SessionScope && other.user == user && other.token == token',
        ),
      );
      expect(session, contains('Object.hashAll([SessionScope, user, token])'));
    });

    test('a marker without values compares by type alone', () {
      final source = generate(const [], childScopes: [childScope('Screen')]);

      final screen = classOf(source, 'ScreenScope');
      expect(
        screen,
        contains('bool operator ==(Object other) => other is ScreenScope;'),
      );
      expect(screen, contains('Object.hashAll([ScreenScope])'));
    });

    test('leaves the environment alone when nothing names one', () {
      final source = generate(
        [declare('Draft', scope: 'Session')],
        childScopes: [childScope('Session')],
      );

      expect(source, isNot(contains('environment')));
    });

    test('a child scope without registrations is still written', () {
      final source = generate(
        const [],
        childScopes: [
          childScope('Screen', values: [value('id', 'NoteId')]),
        ],
      );

      expect(classOf(source, 'ScreenScope'), contains('registerSingleton'));
      expect(source, isNot(contains(r'startCobalt')));
    });
  });

  group('a decorator of what a child scope registers', () {
    test('is applied in that scope, not in the root', () {
      final source = generate(
        [declare('Api', scope: 'Session')],
        childScopes: [childScope('Session')],
        decorators: [decorator('LoggingApi', 'Api')],
      );

      expect(
        classOf(source, 'SessionScope'),
        matches(
          RegExp(
            r'scope\.decorate<_i\d+\.Api>\(\s*const _LoggingApiDecorator\(\)',
          ),
        ),
      );
      expect(classOf(source, 'CobaltRoot'), isNot(contains('decorate')));
    });

    test('is applied in every scope that registers it', () {
      final source = generate(
        [declare('Draft', scope: 'Session'), declare('Draft', scope: 'Editor')],
        childScopes: [childScope('Session'), childScope('Editor')],
        decorators: [decorator('TrackedDraft', 'Draft', allNames: true)],
      );

      expect(classOf(source, 'SessionScope'), contains('decorateAll'));
      expect(classOf(source, 'EditorScope'), contains('decorateAll'));
    });

    test('may inject what that scope and the root register', () {
      expect(
        () => generate(
          [declare('Clock'), declare('Api', scope: 'Session')],
          childScopes: [
            childScope('Session', values: [value('user', 'User')]),
          ],
          decorators: [
            decorator(
              'AuditedApi',
              'Api',
              dependencies: [dep('User'), dep('Clock')],
            ),
          ],
        ),
        returnsNormally,
      );
    });

    test('may not inject what a sibling registers', () {
      expect(
        () => generate(
          [declare('Api', scope: 'Editor')],
          childScopes: [
            childScope('Session', values: [value('user', 'User')]),
            childScope('Editor'),
          ],
          decorators: [
            decorator('AuditedApi', 'Api', dependencies: [dep('User')]),
          ],
        ),
        failsWith(
          allOf(
            contains('AuditedApi in scope Editor requires User'),
            contains('which only scope Session registers'),
          ),
        ),
      );
    });

    test('wraps nothing where its target is left out', () {
      expect(
        () => generate(
          [
            declare('Api', scope: 'Session', environments: {'dev'}),
            declare('Clock', scope: 'Session', environments: {'prod'}),
          ],
          childScopes: [childScope('Session')],
          decorators: [decorator('LoggingApi', 'Api')],
        ),
        failsWith(contains('A decorator wraps a registration nothing makes')),
      );
    });
  });

  group('what a child scope may inject', () {
    test('its own registrations, its values and the root', () {
      expect(
        () => generate(
          [
            declare('Clock'),
            declare('Queue', scope: 'Session'),
            declare(
              'Sync',
              constructor: [dep('Clock'), dep('Queue'), dep('User')],
              scope: 'Session',
            ),
          ],
          childScopes: [
            childScope('Session', values: [value('user', 'User')]),
          ],
        ),
        returnsNormally,
      );
    });

    test('the builder names its marker and its declared parent', () {
      final source = generate(
        [declare('Draft', scope: 'Editor')],
        childScopes: [
          childScope('Session'),
          childScope('Editor', parent: 'Session'),
        ],
      );
      final session = classOf(source, 'SessionScope');
      final editor = classOf(source, 'EditorScope');

      expect(session, matches(RegExp(r'Type get marker => _i\d+\.Session;')));
      expect(session, isNot(contains('get parent')));
      expect(editor, matches(RegExp(r'Type get marker => _i\d+\.Editor;')));
      expect(editor, matches(RegExp(r'Type\? get parent => _i\d+\.Session;')));
    });

    test('what its parent registers', () {
      expect(
        () => generate(
          [
            declare('Draft', constructor: [dep('User')], scope: 'Editor'),
          ],
          childScopes: [
            childScope('Session', values: [value('user', 'User')]),
            childScope('Editor', parent: 'Session'),
          ],
        ),
        returnsNormally,
      );
    });

    test('not what a sibling registers', () {
      expect(
        () => generate(
          [
            declare('Draft', constructor: [dep('User')], scope: 'Editor'),
          ],
          childScopes: [
            childScope('Session', values: [value('user', 'User')]),
            childScope('Editor'),
          ],
        ),
        failsWith(
          allOf(
            contains('Draft in scope Editor requires User'),
            contains('which only scope Session registers'),
          ),
        ),
      );
    });

    test('the root cannot inject what only a child registers', () {
      expect(
        () => generate(
          [
            declare('Api', constructor: [dep('User')]),
          ],
          childScopes: [
            childScope('Session', values: [value('user', 'User')]),
          ],
        ),
        failsWith(
          allOf(
            contains('Api requires User, which only scope Session registers.'),
            contains('@CobaltInject(scope: ...)'),
          ),
        ),
      );
    });

    test('a dependency nothing registers is reported as before', () {
      expect(
        () => generate(
          [
            declare('Draft', constructor: [dep('Clock')], scope: 'Session'),
          ],
          childScopes: [childScope('Session')],
        ),
        failsWith(
          contains(
            'Draft in scope Session requires Clock, which nothing '
            'registers',
          ),
        ),
      );
    });
  });

  group('refused', () {
    test('a registration in a scope this package does not declare', () {
      expect(
        () => generate([declare('Draft', scope: 'Session')]),
        failsWith(contains('declared in another package')),
      );
    });

    test('a value and a registration of one key in one scope', () {
      expect(
        () => generate(
          [declare('User', scope: 'Session')],
          childScopes: [
            childScope('Session', values: [value('user', 'User')]),
          ],
        ),
        failsWith(contains('already registers it as a value')),
      );
    });

    test('two registrations of one key in one scope', () {
      expect(
        () => generate(
          [
            declare('LiveApi', exposeAs: ref('Api'), scope: 'Session'),
            declare('FakeApi', exposeAs: ref('Api'), scope: 'Session'),
          ],
          childScopes: [childScope('Session')],
        ),
        failsWith(contains('both register Api')),
      );
    });

    test('a parent chain that loops', () {
      expect(
        () => generate(
          const [],
          childScopes: [
            childScope('Session', parent: 'Editor'),
            childScope('Editor', parent: 'Session'),
          ],
        ),
        failsWith(contains('is its own ancestor')),
      );
    });

    test('dependsOn across scopes', () {
      expect(
        () => generate(
          [
            declare('Database', isAsyncInit: true),
            declare(
              'Sync',
              isAsyncInit: true,
              dependsOn: [ref('Database')],
              scope: 'Session',
            ),
          ],
          childScopes: [childScope('Session')],
        ),
        failsWith(contains('a registration of the same scope')),
      );
    });
  });

  test('one key in the root and in a child is shadowing, not a conflict', () {
    final source = generate(
      [
        declare('LiveApi', exposeAs: ref('Api')),
        declare('FakeApi', exposeAs: ref('Api'), scope: 'Session'),
      ],
      childScopes: [childScope('Session')],
    );

    expect(classOf(source, 'SessionScope'), contains('_FakeApiFactory'));
    expect(classOf(source, r'CobaltRoot'), contains('_LiveApiFactory'));
  });
}
