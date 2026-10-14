import 'package:test/test.dart';

import 'support.dart';

List<String> bootstrapEntriesOf(String source) {
  final start = source.indexOf(r'cobaltBootstrapSteps');
  if (start < 0) return const [];
  final body = source.substring(start, source.indexOf('];', start));
  return body
      .split('\n')
      .map((line) => line.trim().replaceFirst(RegExp(r'^_i\d+\.'), ''))
      .where((line) => line.endsWith('(),'))
      .toList();
}

void main() {
  group('@CobaltBootstrap emission', () {
    test('emits a typed list of steps', () {
      final source = generate(
        [declare('Logger')],
        bootstrap: [step('BindPlatform')],
      );

      expect(source, contains(r'cobaltBootstrapSteps'));
      expect(source, contains('CobaltBootstrapStep>'));
    });

    test('steps are ordered by their declared order', () {
      final source = generate(
        [declare('Logger')],
        bootstrap: [
          step('LoadEnv', order: 10),
          step('BindPlatform', order: -5),
          step('OpenTracing', order: 0),
        ],
      );

      expect(bootstrapEntriesOf(source), [
        'BindPlatform(),',
        'OpenTracing(),',
        'LoadEnv(),',
      ]);
    });

    test('equal order falls back to a stable alphabetical order', () {
      final source = generate(
        [declare('Logger')],
        bootstrap: [step('Zulu'), step('Alpha'), step('Mike')],
      );

      expect(bootstrapEntriesOf(source), ['Alpha(),', 'Mike(),', 'Zulu(),']);
    });

    test('bootstrap steps generate without any injectables', () {
      final source = generate(const [], bootstrap: [step('BindPlatform')]);

      expect(source, contains(r'cobaltBootstrapSteps'));
      expect(source, isNot(contains(r'CobaltRoot')));
    });

    test('no bootstrap section when nothing is annotated', () {
      final source = generate([declare('Logger')]);

      expect(source, isNot(contains(r'cobaltBootstrapSteps')));
    });
  });
}
