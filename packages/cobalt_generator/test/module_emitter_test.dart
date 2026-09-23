import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('calling the member', () {
    test('a method is called on a const module instance', () {
      final source = generate([
        declare('AppConfig'),
        provide('NetworkModule', 'dio', 'Dio', parameters: [dep('AppConfig')]),
      ]);

      expect(source, contains('const _i'));
      expect(source, contains('.NetworkModule().dio('));
      expect(source, contains('resolver.get<_i'));
    });

    test('a getter is read rather than called', () {
      final source = generate([
        provide('NetworkModule', 'clock', 'Clock', isGetter: true),
      ]);

      expect(source, contains('.NetworkModule().clock'));
      expect(source, isNot(contains('.clock()')));
    });

    test('an async member awaits the call, it does not call init', () {
      final source = generate([
        provide('StorageModule', 'prefs', 'Prefs', isAsyncInit: true),
      ]);

      expect(source, contains('await const _i'));
      expect(source, isNot(contains('.init()')));
      expect(
        registrationsOf(source).single,
        contains('registerAsyncSingleton'),
      );
    });

    test('the factory is named after the module, not the return type', () {
      final source = generate([provide('NetworkModule', 'dio', 'Dio')]);

      expect(source, contains('final class _NetworkModuleDioFactory'));
    });

    test('two modules providing one type do not collide', () {
      final source = generate([
        provide('DevModule', 'client', 'Client', environments: {'dev'}),
        provide('ProdModule', 'client', 'Client', environments: {'prod'}),
      ]);

      expect(source, contains('_DevModuleClientFactory'));
      expect(source, contains('_ProdModuleClientFactory'));
    });
  });

  group('the member joins the ordinary graph', () {
    test('lifetimes map to the same registration calls', () {
      final source = generate([
        provide('M', 'a', 'A', lifetime: CobaltLifetime.transient),
        provide('M', 'b', 'B'),
        provide('M', 'c', 'C', lifetime: CobaltLifetime.singleton),
      ]);

      expect(registrationsOf(source).map((l) => l.split('<').first).toSet(), {
        'scope.registerFactory',
        'scope.registerLazySingleton',
        'scope.registerEagerSingleton',
      });
    });

    test('it is registered after what it depends on', () {
      final source = generate([
        provide('NetworkModule', 'dio', 'Dio', parameters: [dep('AppConfig')]),
        declare('AppConfig'),
      ]);

      final order = registrationsOf(source);
      expect(order.first, contains('AppConfig'));
      expect(order.last, contains('Dio'));
    });

    test('it satisfies a class that injects the type', () {
      final source = generate([
        provide('NetworkModule', 'dio', 'Dio'),
        declare('Api', constructor: [dep('Dio')]),
      ]);

      expect(registrationsOf(source), hasLength(2));
    });

    test('a dependency it needs and nothing provides fails the build', () {
      expect(
        () => generate([
          provide('NetworkModule', 'dio', 'Dio', parameters: [dep('Missing')]),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (e) => e.message,
            'message',
            contains('NetworkModule.dio requires Missing'),
          ),
        ),
      );
    });

    test('a duplicate names the member, not the return type twice', () {
      expect(
        () => generate([
          provide('NetworkModule', 'dio', 'Dio'),
          provide('OtherModule', 'dio', 'Dio'),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (e) => e.message,
            'message',
            contains('NetworkModule.dio and OtherModule.dio both register Dio'),
          ),
        ),
      );
    });

    test('an environment guard wraps the registration', () {
      final source = generate([
        provide('DevModule', 'client', 'Client', environments: {'dev'}),
      ]);

      expect(source, contains("environment.matches(const <String>{'dev'})"));
    });
  });

  group('async ordering is derived, not declared', () {
    test('an async member waits for the async member it takes', () {
      final source = generate([
        provide('DbModule', 'db', 'Database', isAsyncInit: true),
        provide(
          'DbModule',
          'index',
          'SearchIndex',
          isAsyncInit: true,
          parameters: [dep('Database')],
        ),
      ]);

      expect(source, contains('.SearchIndex>('));
      expect(source, contains('dependsOn: {const _i'));
      expect(source, contains('.Database)}'));
    });

    test('a sync dependency does not become an ordering constraint', () {
      final source = generate([
        declare('AppConfig'),
        provide(
          'DbModule',
          'db',
          'Database',
          isAsyncInit: true,
          parameters: [dep('AppConfig')],
        ),
      ]);

      expect(source, isNot(contains('dependsOn:')));
    });
  });

  group('dispose', () {
    test('a top-level function is passed to the registration', () {
      final source = generate([
        provide(
          'NetworkModule',
          'client',
          'Client',
          dispose: const CobaltFunctionRef(
            name: 'closeClient',
            import: appImport,
          ),
        ),
      ]);

      expect(source, contains('dispose: _i'));
      expect(source, contains('.closeClient,'));
    });

    test('a static function is qualified by its class', () {
      final source = generate([
        provide(
          'NetworkModule',
          'client',
          'Client',
          dispose: const CobaltFunctionRef(
            name: 'close',
            import: appImport,
            owner: 'Closers',
          ),
        ),
      ]);

      expect(source, contains('.Closers.close'));
    });
  });

  test('a member taking a named parameter is called by name', () {
    final source = generate([
      declare('Config'),
      provide(
        'NetworkModule',
        'dio',
        'Dio',
        parameters: [dep('Config', isNamed: true, field: 'config')],
      ),
    ]);

    expect(source, contains('config: resolver.get<_i137.Config>()'));
    expect(
      'resolver.get<_i137.Config>()'.allMatches(source).length,
      1,
      reason: 'passed once, by name — not also among the positionals',
    );
  });
}
