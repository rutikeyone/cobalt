import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

CobaltInjectedProperty defaulted(
  String field,
  String type, {
  bool isNamed = true,
}) => CobaltInjectedProperty(
  field: field,
  type: ref(type),
  isNamed: isNamed,
  hasDefault: true,
);

String _flat(String source) => source
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'_i\d+\.'), '')
    .replaceAll('( ', '(')
    .replaceAll(', )', ')');

void main() {
  group('a parameter with a default value', () {
    test('is left out when nothing registers its type', () {
      final source = _flat(
        generate([
          declare('Clock'),
          declare(
            'Api',
            constructor: [dep('Clock'), defaulted('retries', 'int')],
          ),
        ]),
      );

      expect(source, contains('Api(resolver.get<Clock>())'));
      expect(source, isNot(contains('retries')));
    });

    test('is injected when something registers its type', () {
      final source = _flat(
        generate([
          declare('Clock'),
          declare('Api', constructor: [defaulted('clock', 'Clock')]),
        ]),
      );

      expect(source, contains('Api(clock: resolver.get<Clock>())'));
    });

    test('a trailing positional one is left out too', () {
      final source = _flat(
        generate([
          declare('Clock'),
          declare(
            'Api',
            constructor: [
              dep('Clock'),
              defaulted('retries', 'int', isNamed: false),
            ],
          ),
        ]),
      );

      expect(source, contains('Api(resolver.get<Clock>())'));
    });

    test('a positional one before an injected one fails and says why', () {
      expect(
        () => generate([
          declare('Clock'),
          declare(
            'Api',
            constructor: [
              defaulted('retries', 'int', isNamed: false),
              defaulted('clock', 'Clock', isNamed: false),
            ],
          ),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('Api requires int'),
              contains('make it a named parameter'),
            ),
          ),
        ),
      );
    });

    test('registered in one environment, it is still required in the '
        'others', () {
      expect(
        () => generate([
          declare('Clock', environments: const {'prod'}),
          declare('Api', constructor: [defaulted('clock', 'Clock')]),
          declare('Other', environments: const {'dev'}),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('Api requires Clock in dev'),
              isNot(contains('default value')),
            ),
          ),
        ),
      );
    });
  });
}
