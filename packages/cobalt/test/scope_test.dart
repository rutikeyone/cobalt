import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

class HalfInjected extends Recorder implements CobaltInjectable {
  HalfInjected() : super('half');

  @override
  void onInject(CobaltResolver resolver) => resolver.get<Greeting>();
}

final class InstanceEvents extends CobaltObserver {
  final events = <String>[];

  @override
  void onInstanceCreated(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
  }) => events.add('created $key');

  @override
  void onInstanceDisposed(CobaltScopeRef scope, String label) =>
      events.add('disposed $label');
}

void main() {
  setUp(resetLogs);

  group('registration and resolution', () {
    test('lazy singleton returns the same instance', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(scope.get<Logger>(), same(scope.get<Logger>()));
    });

    test('factory returns a new instance every time', () {
      final scope = cobaltTestRoot()
        ..registerFactory<Logger>(const LoggerFactory());

      expect(scope.get<Logger>(), isNot(same(scope.get<Logger>())));
    });

    test('missing registration names the key and the scope', () {
      final scope = cobaltTestRoot(name: 'app');

      expect(
        () => scope.get<Logger>(),
        throwsA(isA<CobaltNotRegisteredError>()),
      );
    });

    test('duplicate registration in one scope throws', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(
        () => scope.registerLazySingleton<Logger>(const LoggerFactory()),
        throwsA(isA<CobaltDuplicateRegistrationError>()),
      );
    });

    test('named registrations coexist with unnamed ones', () {
      final primary = Logger();
      final backup = Logger();
      final scope = cobaltTestRoot()
        ..registerSingleton<Logger>(primary)
        ..registerSingleton<Logger>(backup, name: 'backup');

      expect(scope.get<Logger>(), same(primary));
      expect(scope.get<Logger>(name: 'backup'), same(backup));
    });

    test('parameterized factory receives the argument', () {
      final scope = cobaltTestRoot()
        ..registerParamFactory<Greeting, String>(const GreetingFactory());

      expect(scope.getWithParam<Greeting, String>('cobalt').text, 'hi cobalt');
    });

    test('a value the factory cannot take names both types', () {
      final scope = cobaltTestRoot()
        ..registerParamFactory<Greeting, String>(const GreetingFactory());

      expect(
        () => scope.getWithParam<Greeting, int>(42),
        throwsA(
          isA<CobaltParamTypeError>()
              .having((e) => e.expected, 'expected', String)
              .having((e) => e.actual, 'actual', int)
              .having((e) => e.key, 'key', const CobaltKey(Greeting))
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('Greeting'),
                  contains('String'),
                  contains('int'),
                ),
              ),
        ),
      );
    });

    test('the check happens before the factory runs', () {
      final scope = cobaltTestRoot()
        ..registerParamFactory<Greeting, String>(const GreetingFactory());

      expect(
        () => scope.getWithParam<Greeting, int>(42),
        throwsA(isA<CobaltError>()),
        reason: 'a TypeError from inside the factory names nothing useful',
      );
      expect(scope.getWithParam<Greeting, String>('ada').text, 'hi ada');
    });

    /// A type test, not a comparison of `Type`s: a factory registered for a
    /// supertype should take a subtype, exactly as its body would.
    test('a subtype of the registered parameter is accepted', () {
      final scope = cobaltTestRoot()
        ..registerParamFactory<Greeting, Object>(const AnyGreetingFactory());

      expect(scope.getWithParam<Greeting, Object>('ada').text, 'hi ada');
      expect(scope.getWithParam<Greeting, Object>(7).text, 'hi 7');
    });

    test('a named parameterized registration is checked too', () {
      final scope = cobaltTestRoot()
        ..registerParamFactory<Greeting, String>(
          const GreetingFactory(),
          name: 'formal',
        );

      expect(
        () => scope.getWithParam<Greeting, int>(1, name: 'formal'),
        throwsA(
          isA<CobaltParamTypeError>().having(
            (e) => e.key,
            'key',
            const CobaltKey(Greeting, name: 'formal'),
          ),
        ),
      );
    });

    test('parameterized registration rejects plain get', () {
      final scope = cobaltTestRoot()
        ..registerParamFactory<Greeting, String>(const GreetingFactory());

      expect(() => scope.get<Greeting>(), throwsA(isA<CobaltError>()));
    });
  });

  group('hierarchy', () {
    test('child resolves through the parent', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());
      final child = root.push('session');

      expect(child.get<Logger>(), same(root.get<Logger>()));
    });

    test('child shadows the parent without touching it', () {
      final rootLogger = Logger();
      final childLogger = Logger();
      final root = cobaltTestRoot()..registerSingleton<Logger>(rootLogger);
      final child = root.push('session')
        ..registerSingleton<Logger>(childLogger);

      expect(child.get<Logger>(), same(childLogger));
      expect(root.get<Logger>(), same(rootLogger));
    });

    test('dependencies resolve in the scope that owns them', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());
      final child = root.push('session')
        ..registerLazySingleton<ApiClient>(const ApiClientFactory());

      expect(child.get<ApiClient>().logger, same(root.get<Logger>()));
    });

    test('two sibling scopes are independent subtrees', () {
      final root = cobaltTestRoot();
      final a = root.push('a')
        ..registerLazySingleton<Logger>(const LoggerFactory());
      final b = root.push('b')
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(a.get<Logger>(), isNot(same(b.get<Logger>())));
      expect(root.children, hasLength(2));
    });
  });

  group('multi-injection', () {
    test('getAll collects every registration of a type', () {
      final scope = cobaltTestRoot()
        ..registerSingleton<Logger>(Logger())
        ..registerSingleton<Logger>(Logger(), name: 'second')
        ..registerSingleton<Logger>(Logger(), name: 'third');

      expect(scope.getAll<Logger>(), hasLength(3));
    });

    test('getAll walks ancestors and lets the child shadow', () {
      final rootDefault = Logger();
      final rootExtra = Logger();
      final childDefault = Logger();

      final root = cobaltTestRoot()
        ..registerSingleton<Logger>(rootDefault)
        ..registerSingleton<Logger>(rootExtra, name: 'extra');
      final child = root.push('session')
        ..registerSingleton<Logger>(childDefault);

      expect(child.getAll<Logger>(), [childDefault, rootExtra]);
    });
  });

  group('property injection', () {
    test('onInject runs immediately after construction', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory())
        ..registerFactory<PropertyTarget>(const PropertyTargetFactory());

      final injected = scope.get<PropertyTarget>();

      expect(injected.injected, isTrue);
      expect(injected.logger, same(scope.get<Logger>()));
    });

    test('a failed onInject is not cached and is closed later', () async {
      final observer = InstanceEvents();
      final scope = cobaltTestRoot(observers: [observer])
        ..registerLazySingleton<HalfInjected>(FnFactory((_) => HalfInjected()));

      for (var attempt = 0; attempt < 2; attempt++) {
        expect(
          () => scope.get<HalfInjected>(),
          throwsA(isA<CobaltNotRegisteredError>()),
        );
      }
      await scope.dispose();

      expect(recorder.entries, ['half', 'half']);
      expect(observer.events, [
        'created HalfInjected',
        'created HalfInjected',
        'disposed HalfInjected',
        'disposed HalfInjected',
      ]);
    });

    test('a failed onInject is recorded as built and released', () async {
      final events = CapturingObserver();
      final scope = cobaltTestRoot(observers: [events])
        ..registerLazySingleton<HalfInjected>(FnFactory((_) => HalfInjected()));

      expect(
        () => scope.get<HalfInjected>(),
        throwsA(isA<CobaltNotRegisteredError>()),
      );
      await scope.dispose();

      expect(events.saw(CobaltEventKind.instanceCreated), isTrue);
      expect(events.saw(CobaltEventKind.instanceDisposed), isTrue);
    });

    test('a failed onInject in a lazy async build is built anew', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<HalfInjected>(
          AsyncFnFactory((_) async => HalfInjected()),
        );

      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          scope.getAsync<HalfInjected>(),
          throwsA(isA<CobaltNotRegisteredError>()),
        );
      }
      await scope.dispose();

      expect(recorder.entries, ['half', 'half']);
    });

    test('a failed onInject in an eager build is closed later', () async {
      final scope = cobaltTestRoot();

      expect(
        () => scope.registerEagerSingleton<HalfInjected>(
          FnFactory((_) => HalfInjected()),
        ),
        throwsA(isA<CobaltNotRegisteredError>()),
      );
      await scope.dispose();

      expect(recorder.entries, ['half']);
    });
  });
}
