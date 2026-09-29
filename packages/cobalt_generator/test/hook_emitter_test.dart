import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('an @CobaltHookAll class', () {
    test('is added with hookAll on its target, labelled by its class', () {
      final source = generate(
        [declare('Api')],
        hooks: [hook('JoinRegistry', 'Loggable')],
      );

      expect(
        hooksOf(source).single,
        matches(
          RegExp(
            r'scope\.hookAll<_i\d+\.Loggable>\(_i\d+\.JoinRegistry\(\), '
            r"debugLabel: 'JoinRegistry',? ?\);",
          ),
        ),
      );
    });

    test('comes before every registration, so an eager one passes through', () {
      final source = generate(
        [declare('Api', lifetime: CobaltLifetime.singleton)],
        hooks: [hook('JoinRegistry', 'Loggable')],
      );

      expect(
        source.indexOf('scope.hookAll'),
        lessThan(source.indexOf('scope.register')),
      );
    });

    test('several are added by order, then by class name', () {
      final source = generate(
        [declare('Api')],
        hooks: [
          hook('Zeta', 'Loggable'),
          hook('Late', 'Loggable', order: 5),
          hook('Alpha', 'Loggable'),
          hook('Early', 'Loggable', order: -1),
        ],
      );

      expect(
        hooksOf(source).map(
          (line) => RegExp(r"debugLabel: '(\w+)'").firstMatch(line)!.group(1),
        ),
        ['Early', 'Alpha', 'Zeta', 'Late'],
      );
    });

    test('restricted to an environment is added only in that one', () {
      final source = generate(
        [declare('Api')],
        hooks: [
          hook('DevOnly', 'Loggable', environments: {'dev'}),
        ],
      );

      expect(
        source,
        matches(
          RegExp(
            r"if \(environment\.matches\(const <String>\{'dev'\}\)\) \{\s*"
            r'scope\.hookAll',
          ),
        ),
      );
    });

    test('alone is enough for a root scope and a start function', () {
      final source = generate(
        const [],
        hooks: [hook('JoinRegistry', 'Loggable')],
      );

      expect(source, contains(r'class $CobaltRootScope'));
      expect(hooksOf(source), hasLength(1));
    });
  });
}
