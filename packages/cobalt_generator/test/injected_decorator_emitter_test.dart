import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher failsWith(Object message) => throwsA(
  isA<CobaltGenerationError>().having((e) => e.message, 'message', message),
);

void main() {
  group('a decorator with @injected fields', () {
    test('fills them right after construction, from the same resolver', () {
      final source = generate(
        [declare('Api'), declare('Logger')],
        decorators: [
          decorator('LoggingApi', 'Api', injectedFields: [dep('Logger')]),
        ],
      );

      expect(
        source,
        matches(
          RegExp(
            r'decorate\(\s*_i\d+\.Api inner,\s*_i\d+\.CobaltResolver resolver,?'
            r'\s*\)\s*=>\s*_i\d+\.LoggingApi\(inner\)\.\.onInject\(resolver\);',
          ),
        ),
      );
    });

    test('without them, onInject is never called', () {
      final source = generate(
        [declare('Api')],
        decorators: [decorator('LoggingApi', 'Api')],
      );

      expect(source, isNot(contains('onInject')));
    });

    test('its fields order the registrations it wraps', () {
      final source = generate(
        [declare('Api'), declare('Logger')],
        decorators: [
          decorator('LoggingApi', 'Api', injectedFields: [dep('Logger')]),
        ],
      );

      final body = source.substring(source.indexOf('void build('));
      expect(
        body.indexOf(RegExp(r'register\w+<_i\d+\.Logger>')),
        lessThan(body.indexOf(RegExp(r'register\w+<_i\d+\.Api>'))),
      );
    });
  });

  group('what the build refuses', () {
    test('a field of a type nothing registers', () {
      expect(
        () => generate(
          [declare('Api')],
          decorators: [
            decorator('LoggingApi', 'Api', injectedFields: [dep('Logger')]),
          ],
        ),
        failsWith(
          allOf(contains('LoggingApi requires Logger'), contains('nothing')),
        ),
      );
    });

    test('a field of a lazy async type', () {
      expect(
        () => generate(
          [declare('Api'), declare('Engine', isLazyAsync: true)],
          decorators: [
            decorator('LoggingApi', 'Api', injectedFields: [dep('Engine')]),
          ],
        ),
        failsWith(contains('LoggingApi injects Engine')),
      );
    });

    test('a field that depends on its own target', () {
      expect(
        () => generate(
          [
            declare('Api'),
            declare('Session', constructor: [dep('Api')]),
          ],
          decorators: [
            decorator('TrackedApi', 'Api', injectedFields: [dep('Session')]),
          ],
        ),
        throwsA(isA<CobaltCycleError>()),
      );
    });
  });
}
