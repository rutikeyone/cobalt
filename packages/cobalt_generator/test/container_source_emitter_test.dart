import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('factory emission', () {
    test('emits a const class, never a closure', () {
      final source = generate([declare('Logger')]);

      expect(source, contains('final class _LoggerFactory'));
      expect(source, contains('const _LoggerFactory();'));
    });

    test('constructor dependencies become resolver calls', () {
      final source = generate([
        declare('Logger'),
        declare('Api', constructor: [dep('Logger')]),
      ]);

      expect(source, contains('resolver.get<_i'));
      expect(source, contains('.Logger>()'));
    });

    test('named dependencies keep their name', () {
      final source = generate([
        declare('Logger', name: 'audit'),
        declare('Api', constructor: [dep('Logger', name: 'audit')]),
      ]);

      expect(source, contains("name: 'audit'"));
      expect(source, contains('_LoggerAuditFactory'));
    });

    test('exposeAs registers the interface, not the implementation', () {
      final source = generate([
        declare('SqlRepository', exposeAs: ref('Repository')),
      ]);

      expect(source, contains('CobaltFactory<_i'));
      expect(source, contains('.Repository>'));
      expect(source, contains('.SqlRepository()'));
    });
  });

  group('lifetimes', () {
    test('each lifetime maps to its own registration call', () {
      final source = generate([
        declare('A', lifetime: CobaltLifetime.transient),
        declare('B', lifetime: CobaltLifetime.lazySingleton),
        declare('C', lifetime: CobaltLifetime.singleton),
      ]);

      expect(registrationsOf(source).map((l) => l.split('<').first).toSet(), {
        'scope.registerFactory',
        'scope.registerLazySingleton',
        'scope.registerEagerSingleton',
      });
    });

    test('an eager singleton is built by the scope, not before it', () {
      final source = generate([
        declare('Config', lifetime: CobaltLifetime.singleton),
      ]);

      expect(
        source,
        contains(
          'registerEagerSingleton<_i137.Config>(const _ConfigFactory())',
        ),
      );
      expect(
        source,
        isNot(contains('.create(scope)')),
        reason: 'built before the call, it could not be skipped by an override',
      );
    });
  });

  group('registration order', () {
    test('dependencies are registered before their dependents', () {
      final source = generate([
        declare('Bloc', properties: [dep('Api')]),
        declare('Api', constructor: [dep('Logger')]),
        declare('Logger'),
      ]);

      final order = registrationsOf(source);
      expect(order[0], contains('Logger'));
      expect(order[1], contains('Api'));
      expect(order[2], contains('Bloc'));
    });

    test('property injection counts as a dependency edge', () {
      final source = generate([
        declare('Bloc', properties: [dep('Logger')]),
        declare('Logger'),
      ]);

      final order = registrationsOf(source);
      expect(order.first, contains('Logger'));
      expect(order.last, contains('Bloc'));
    });

    test('a cycle fails generation instead of emitting broken code', () {
      expect(
        () => generate([
          declare('A', constructor: [dep('B')]),
          declare('B', constructor: [dep('A')]),
        ]),
        throwsA(isA<CobaltCycleError>()),
      );
    });
  });

  test('import prefixes are stable across runs', () {
    final descriptors = [declare('Logger'), declare('Api')];

    expect(generate(descriptors), generate(descriptors.reversed.toList()));
  });

  group('a class that names its own dispose function', () {
    test('passes it to the registration', () {
      final source = generate([
        declare(
          'Ticker',
          dispose: const CobaltFunctionRef(
            name: 'closeTicker',
            import: appImport,
          ),
        ),
      ]);

      expect(
        source,
        contains('dispose: _i'),
        reason:
            'the annotation was read only for module members before, so a '
            'class naming one registered without it and the instance was '
            'never closed',
      );
      expect(source, contains('.closeTicker,'));
    });

    test('a class that names none registers without one', () {
      expect(generate([declare('Ticker')]), isNot(contains('dispose:')));
    });
  });
}
