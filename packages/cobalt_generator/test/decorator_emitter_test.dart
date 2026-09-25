import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher failsWith(Object message) => throwsA(
  isA<CobaltGenerationError>().having((e) => e.message, 'message', message),
);

void main() {
  group('the emitted decorator', () {
    test('is a const class building the wrapper around inner', () {
      final source = generate(
        [declare('Api'), declare('Logger')],
        decorators: [
          decorator('LoggingApi', 'Api', dependencies: [dep('Logger')]),
        ],
      );

      expect(source, contains('final class _LoggingApiDecorator'));
      expect(
        source,
        matches(RegExp(r'implements _i\d+\.CobaltDecorator<_i\d+\.Api>')),
      );
      expect(source, contains('const _LoggingApiDecorator();'));
      expect(
        source,
        matches(
          RegExp(
            r'decorate\(\s*_i\d+\.Api inner,\s*_i\d+\.CobaltResolver resolver,?'
            r'\s*\)\s*=>\s*_i\d+\.LoggingApi\(inner, '
            r'resolver\.get<_i\d+\.Logger>\(\)\)',
          ),
        ),
      );
    });

    test('a named inner is passed by name', () {
      final source = generate(
        [declare('Api')],
        decorators: [decorator('LoggingApi', 'Api', innerIsNamed: true)],
      );

      expect(source, contains('LoggingApi(inner: inner)'));
    });

    test('a nullable dependency reads through getOrNull', () {
      final source = generate(
        [declare('Api')],
        decorators: [
          decorator(
            'LoggingApi',
            'Api',
            dependencies: [dep('Logger', isNullable: true)],
          ),
        ],
      );

      expect(source, contains('resolver.getOrNull<'));
    });

    test('two decorator classes of one name do not collide', () {
      final source = generate(
        [declare('Api'), declare('Store')],
        decorators: [
          decorator('Audit', 'Api', import: 'package:app/a.dart'),
          decorator('Audit', 'Store', import: 'package:app/b.dart'),
        ],
      );

      final names = RegExp(
        r'final class (_AuditDecorator\S*) ',
      ).allMatches(source).map((m) => m.group(1)).toSet();
      expect(names, hasLength(2));
      expect(names, isNot(contains('_AuditDecorator')));
    });
  });

  group('build()', () {
    test('decorates after every registration, with the target type', () {
      final source = generate(
        [declare('Api', name: 'primary')],
        decorators: [decorator('LoggingApi', 'Api', name: 'primary')],
      );

      final body = source.substring(source.indexOf('void build('));
      expect(
        body.indexOf('scope.decorate'),
        greaterThan(body.indexOf('scope.register')),
      );
      expect(
        decorationsOf(source).single,
        matches(
          RegExp(
            r"scope\.decorate<_i\d+\.Api>\(const _LoggingApiDecorator\(\), "
            r"name: 'primary'\);",
          ),
        ),
      );
    });

    test('the order decides which is innermost, not the source order', () {
      final source = generate(
        [declare('Api')],
        decorators: [
          decorator('Retrying', 'Api', order: 2),
          decorator('Caching', 'Api', order: 1),
        ],
      );

      final decorations = decorationsOf(source);
      expect(decorations.first, contains('_CachingDecorator'));
      expect(decorations.last, contains('_RetryingDecorator'));
    });

    test('an environment guards the decoration', () {
      final source = generate(
        [declare('Api')],
        decorators: [
          decorator('LoggingApi', 'Api', environments: {'dev'}),
        ],
      );

      expect(
        source,
        contains("if (environment.matches(const <String>{'dev'}))"),
      );
      expect(source, contains('CobaltEnvironment environment'));
    });

    test('decorating only what the root promises still emits a container', () {
      final source = generate(
        const [],
        scopeRoots: [
          scopeRoot('AppScope', provides: [provided('Api')]),
        ],
        decorators: [decorator('LoggingApi', 'Api')],
      );

      expect(source, contains(r'final class $CobaltRootScope'));
      expect(decorationsOf(source), hasLength(1));
      expect(source, contains(r'$startCobalt'));
    });
  });

  group('what the build refuses', () {
    test('decorating something nothing registers', () {
      expect(
        () => generate(
          [declare('Store')],
          decorators: [decorator('LoggingApi', 'Api')],
        ),
        failsWith(
          allOf(
            contains('LoggingApi decorates Api'),
            contains('@CobaltScopeRoot(provides: [...])'),
          ),
        ),
      );
    });

    test(
      'decorating the unnamed registration when only a named one exists',
      () {
        expect(
          () => generate(
            [declare('Api', name: 'primary')],
            decorators: [decorator('LoggingApi', 'Api')],
          ),
          failsWith(contains('LoggingApi decorates Api')),
        );
      },
    );

    test('a target missing in one environment names that environment', () {
      expect(
        () => generate(
          [
            declare('Api', environments: {'prod'}),
            declare('Other', environments: {'dev'}),
          ],
          decorators: [decorator('LoggingApi', 'Api')],
        ),
        failsWith(contains('LoggingApi decorates Api in dev')),
      );
    });

    test('a dependency of the decorator nothing registers', () {
      expect(
        () => generate(
          [declare('Api')],
          decorators: [
            decorator('LoggingApi', 'Api', dependencies: [dep('Logger')]),
          ],
        ),
        failsWith(contains('LoggingApi requires Logger')),
      );
    });

    test('two decorators of one registration without an order', () {
      expect(
        () => generate(
          [declare('Api')],
          decorators: [
            decorator('Caching', 'Api', order: 1),
            decorator('Retrying', 'Api'),
          ],
        ),
        failsWith(contains('do not say which wraps which')),
      );
    });

    test('two decorators with the same order', () {
      expect(
        () => generate(
          [declare('Api')],
          decorators: [
            decorator('Caching', 'Api', order: 1),
            decorator('Retrying', 'Api', order: 1),
          ],
        ),
        failsWith(contains('with order 1')),
      );
    });

    test('decorators in disjoint environments need no order', () {
      final source = generate(
        [declare('Api')],
        decorators: [
          decorator('DevLog', 'Api', environments: {'dev'}),
          decorator('ProdLog', 'Api', environments: {'prod'}),
        ],
      );

      expect(decorationsOf(source), hasLength(2));
    });

    test('a decorator taking a lazy async registration', () {
      expect(
        () => generate(
          [declare('Api'), declare('Index', isLazyAsync: true)],
          decorators: [
            decorator('LoggingApi', 'Api', dependencies: [dep('Index')]),
          ],
        ),
        failsWith(contains('A decorator cannot take a lazy async')),
      );
    });

    test('a decorator needing something that depends on its target', () {
      expect(
        () => generate(
          [
            declare('Api'),
            declare('Audit', constructor: [dep('Api')]),
          ],
          decorators: [
            decorator('LoggingApi', 'Api', dependencies: [dep('Audit')]),
          ],
        ),
        throwsA(isA<CobaltCycleError>()),
      );
    });
  });

  group('the graph around it', () {
    test("a decorator's dependency is registered before its target", () {
      final order = registrationsOf(
        generate(
          [
            declare('Api', lifetime: CobaltLifetime.singleton),
            declare('Logger', lifetime: CobaltLifetime.singleton),
          ],
          decorators: [
            decorator('LoggingApi', 'Api', dependencies: [dep('Logger')]),
          ],
        ),
      );

      expect(order.indexWhere((l) => l.contains('Logger')), 0);
    });

    Matcher waitsFor(String consumer, String dependency) => matches(
      RegExp(
        'registerAsyncSingleton<_i\\d+\\.$consumer>\\([^;]*'
        'dependsOn: \\{[^}]*CobaltKey\\(_i\\d+\\.$dependency\\)',
      ),
    );

    test('an async consumer waits for what the decorator of its dependency '
        'resolves', () {
      final source = generate(
        [
          declare('Database', isAsyncInit: true),
          declare('Clock', isAsyncInit: true),
          declare(
            'SearchIndex',
            isAsyncInit: true,
            constructor: [dep('Database')],
            dependsOn: [ref('Database')],
          ),
        ],
        decorators: [
          decorator('TimedDatabase', 'Database', dependencies: [dep('Clock')]),
        ],
      );

      expect(source, waitsFor('SearchIndex', 'Clock'));
      expect(source, waitsFor('SearchIndex', 'Database'));
      expect(
        source,
        isNot(waitsFor('Database', 'Clock')),
        reason:
            'the wait sits on the consumer: an override of Database would '
            'drop an edge written on Database itself',
      );
    });

    test('a decorated registration reached through a synchronous one counts '
        'too', () {
      final source = generate(
        [
          declare('Api'),
          declare('Gateway', constructor: [dep('Api')]),
          declare('Clock', isAsyncInit: true),
          declare('Sync', isAsyncInit: true, constructor: [dep('Gateway')]),
        ],
        decorators: [
          decorator('TimedApi', 'Api', dependencies: [dep('Clock')]),
        ],
      );

      expect(source, waitsFor('Sync', 'Clock'));
    });

    test('a dependency missing from some environment of the consumer is not '
        'awaited', () {
      final source = generate(
        [
          declare('Database', isAsyncInit: true),
          declare('Clock', isAsyncInit: true, environments: {'prod'}),
          declare('Other', environments: {'dev'}),
          declare(
            'SearchIndex',
            isAsyncInit: true,
            constructor: [dep('Database')],
          ),
        ],
        decorators: [
          decorator(
            'TimedDatabase',
            'Database',
            dependencies: [dep('Clock')],
            environments: {'prod'},
          ),
        ],
      );

      expect(source, isNot(contains('dependsOn')));
    });
  });
}
