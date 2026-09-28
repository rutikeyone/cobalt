import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher failsWith(Object message) => throwsA(
  isA<CobaltGenerationError>().having((e) => e.message, 'message', message),
);

void main() {
  group('a decorator of every registration of a type', () {
    test('is emitted as decorateAll, without a name', () {
      final source = generate(
        [declare('Api'), declare('Api', name: 'auth')],
        decorators: [decorator('LoggingApi', 'Api', allNames: true)],
      );

      expect(
        decorationsOf(source).single,
        matches(
          RegExp(
            r'scope\.decorateAll<_i\d+\.Api>\(const _LoggingApiDecorator\(\), '
            r"debugLabel: 'LoggingApi',? ?\);",
          ),
        ),
      );
    });

    test('is satisfied by a named registration alone', () {
      expect(
        () => generate(
          [declare('Api', name: 'auth')],
          decorators: [decorator('LoggingApi', 'Api', allNames: true)],
        ),
        returnsNormally,
      );
    });

    test('is satisfied by a type named in provides', () {
      expect(
        () => generate(
          const [],
          scopeRoots: [
            scopeRoot('AppScope', provides: [provided('Api', name: 'auth')]),
          ],
          decorators: [decorator('LoggingApi', 'Api', allNames: true)],
        ),
        returnsNormally,
      );
    });

    test('takes its place among the decorators of a key by order', () {
      final source = generate(
        [declare('Api', name: 'auth')],
        decorators: [
          decorator('Caching', 'Api', name: 'auth', order: 3),
          decorator('Logging', 'Api', allNames: true, order: 2),
          decorator('Retrying', 'Api', name: 'auth', order: 1),
        ],
      );

      final decorations = decorationsOf(source);
      expect(decorations[0], contains('_RetryingDecorator'));
      expect(decorations[1], contains('decorateAll'));
      expect(decorations[2], contains('_CachingDecorator'));
    });

    test('its dependencies order every registration of the type', () {
      final source = generate(
        [
          declare('Clock'),
          declare('Api', name: 'auth'),
          declare('Screen', constructor: [dep('Api', name: 'auth')]),
        ],
        decorators: [
          decorator(
            'Stamped',
            'Api',
            allNames: true,
            dependencies: [dep('Clock')],
          ),
        ],
      );

      final body = source.substring(source.indexOf('void build('));
      final clock = body.indexOf(RegExp(r'register\w+<_i\d+\.Clock>'));
      final api = body.indexOf(RegExp(r'register\w+<_i\d+\.Api>'));
      expect(clock, isNonNegative);
      expect(api, isNonNegative);
      expect(clock, lessThan(api));
    });

    test('an eager async consumer waits for its async dependencies', () {
      final source = generate(
        [
          declare('Database', isAsyncInit: true),
          declare('Api', name: 'auth'),
          declare(
            'Warmup',
            isAsyncInit: true,
            constructor: [dep('Api', name: 'auth')],
          ),
        ],
        decorators: [
          decorator(
            'Audited',
            'Api',
            allNames: true,
            dependencies: [dep('Database')],
          ),
        ],
      );

      expect(
        source,
        matches(
          RegExp(
            r'registerAsyncSingleton<_i\d+\.Warmup>\([^;]*dependsOn: '
            r'\{[^}]*CobaltKey\(_i\d+\.Database\)',
          ),
        ),
      );
    });
  });

  group('what the build refuses', () {
    test('a type nothing registers', () {
      expect(
        () => generate(
          [declare('Store')],
          decorators: [decorator('LoggingApi', 'Api', allNames: true)],
        ),
        failsWith(
          allOf(
            contains('wraps a registration nothing makes'),
            contains('LoggingApi decorates every Api'),
          ),
        ),
      );
    });

    test('two decorators of one key without an order, across both kinds', () {
      expect(
        () => generate(
          [declare('Api', name: 'auth')],
          decorators: [
            decorator('Caching', 'Api', name: 'auth'),
            decorator('Logging', 'Api', allNames: true),
          ],
        ),
        failsWith(
          allOf(
            contains('do not say which wraps which'),
            contains("Api named 'auth'"),
          ),
        ),
      );
    });

    test('the same order on a key and on its type', () {
      expect(
        () => generate(
          [declare('Api')],
          decorators: [
            decorator('Caching', 'Api', order: 1),
            decorator('Logging', 'Api', allNames: true, order: 1),
          ],
        ),
        failsWith(contains('with order 1')),
      );
    });

    test('a cycle through its dependencies', () {
      expect(
        () => generate(
          [
            declare('Api', name: 'auth'),
            declare('Session', constructor: [dep('Api', name: 'auth')]),
          ],
          decorators: [
            decorator(
              'Tracked',
              'Api',
              allNames: true,
              dependencies: [dep('Session')],
            ),
          ],
        ),
        throwsA(isA<CobaltCycleError>()),
      );
    });
  });
}
