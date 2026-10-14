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
          'final class SessionScope implements _i573.CobaltScopeBuilder',
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
      expect(session, contains('this.environment ='));
      expect(session, contains("environment.matches(const <String>{'prod'})"));
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

    test('a decorator of what only a child scope registers', () {
      expect(
        () => generate(
          [declare('Api', scope: 'Session')],
          childScopes: [childScope('Session')],
          decorators: [decorator('LoggingApi', 'Api')],
        ),
        failsWith(contains('applies decorators in the root only')),
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
