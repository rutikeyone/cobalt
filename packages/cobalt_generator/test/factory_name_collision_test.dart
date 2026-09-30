import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A class of [name] declared in [library], which `declare` cannot express:
/// its fixtures all come from one import, and a collision needs two.
CobaltInjectableClass declareIn(String library, String name) =>
    CobaltInjectableClass(
      type: CobaltTypeRef(name: name, import: library),
      lifetime: CobaltLifetime.lazySingleton,
      constructorParameters: const [],
      properties: const [],
    );

const _core = 'package:app/core/telemetry.dart';
const _feature = 'package:app/feature/telemetry.dart';

void main() {
  group('two libraries declaring the same class name', () {
    test('do not both emit the same factory class', () {
      final source = generate([
        declareIn(_core, 'Telemetry'),
        declareIn(_feature, 'Telemetry'),
      ]);

      expect(
        '_TelemetryFactory'.allMatches(source).length,
        greaterThan(0),
        reason: 'the base name is still the readable part of both',
      );
      expect(
        RegExp(
          r'final class (_TelemetryFactory\S*)',
        ).allMatches(source).map((match) => match.group(1)).toSet(),
        hasLength(2),
        reason: 'two declarations, two classes, two names',
      );
    });

    test('neither of them keeps the plain name', () {
      final source = generate([
        declareIn(_core, 'Telemetry'),
        declareIn(_feature, 'Telemetry'),
      ]);

      expect(
        source,
        isNot(contains('final class _TelemetryFactory implements')),
        reason:
            'suffixing only one of them would make the name depend on which '
            'was visited first',
      );
    });

    test('are named the same whichever order they arrive in', () {
      final forwards = generate([
        declareIn(_core, 'Telemetry'),
        declareIn(_feature, 'Telemetry'),
      ]);
      final backwards = generate([
        declareIn(_feature, 'Telemetry'),
        declareIn(_core, 'Telemetry'),
      ]);

      expect(_factoryNamesIn(forwards), _factoryNamesIn(backwards));
    });
  });

  test('a name nobody contests is left exactly as it was', () {
    final source = generate([
      declareIn(_core, 'Telemetry'),
      declareIn(_feature, 'Reporter'),
    ]);

    expect(
      source,
      matches(RegExp(r'final class _TelemetryFactory\s+implements')),
    );
    expect(
      source,
      matches(RegExp(r'final class _ReporterFactory\s+implements')),
      reason: 'adding a second class must not rename anything else',
    );
  });
}

Set<String> _factoryNamesIn(String source) => RegExp(
  r'final class (_\S+Factory\S*)',
).allMatches(source).map((match) => match.group(1)!).toSet();
