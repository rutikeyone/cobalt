import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

class DevWithMocks extends CobaltEnvironment {
  const DevWithMocks() : super('dev');

  @override
  bool matches(Set<String> environments) =>
      super.matches(environments) || environments.contains('mock');
}

void main() {
  group('CobaltEnvironment', () {
    test('an unrestricted registration belongs to every environment', () {
      for (final environment in const [
        CobaltEnvironment.dev,
        CobaltEnvironment.stage,
        CobaltEnvironment.prod,
        CobaltEnvironment.test,
        CobaltEnvironment('canary'),
      ]) {
        expect(environment.matches(const {}), isTrue);
      }
    });

    test('the default environment holds an unsplit graph and nothing more', () {
      const environment = CobaltEnvironment.defaultEnvironment;

      expect(environment.matches(const {}), isTrue);
      expect(environment.matches(const {'dev'}), isFalse);
      expect(environment.matches(const {'prod'}), isFalse);
      expect(
        environment.matches(const {'default'}),
        isTrue,
        reason: 'naming it explicitly is allowed, if pointless',
      );
    });

    test('a restricted registration belongs only where it is named', () {
      expect(CobaltEnvironment.dev.matches(const {'dev'}), isTrue);
      expect(CobaltEnvironment.dev.matches(const {'prod'}), isFalse);
      expect(CobaltEnvironment.dev.matches(const {'dev', 'stage'}), isTrue);
    });

    test('a name of your own is not second class', () {
      const canary = CobaltEnvironment('canary');

      expect(canary.matches(const {'canary'}), isTrue);
      expect(canary.matches(const {}), isTrue);
      expect(CobaltEnvironment.prod.matches(const {'canary'}), isFalse);
    });

    test('matching can be widened by subclassing', () {
      const environment = DevWithMocks();

      expect(environment.matches(const {'dev'}), isTrue);
      expect(environment.matches(const {'mock'}), isTrue);
      expect(environment.matches(const {'prod'}), isFalse);
    });

    test('equality is by name, and a subclass is not its base', () {
      expect(const CobaltEnvironment('dev'), equals(CobaltEnvironment.dev));
      expect(
        const CobaltEnvironment('dev'),
        isNot(equals(const DevWithMocks())),
      );
      expect(CobaltEnvironment.dev, isNot(equals(CobaltEnvironment.prod)));
    });
  });

  group('the environment of a scope', () {
    test('is null until something sets it', () {
      expect(cobaltTestRoot().environment, isNull);
    });

    test('is read by every scope below the one that set it', () {
      final root = cobaltTestRoot()..useEnvironment(CobaltEnvironment.prod);
      final session = root.push('session');
      final screen = session.push('screen');

      expect(session.environment, CobaltEnvironment.prod);
      expect(screen.environment, CobaltEnvironment.prod);
    });

    test('set on a child, applies to it and below, not above', () {
      final root = cobaltTestRoot()..useEnvironment(CobaltEnvironment.prod);
      final session = root.push('session')
        ..useEnvironment(CobaltEnvironment.dev);

      expect(session.push('screen').environment, CobaltEnvironment.dev);
      expect(root.environment, CobaltEnvironment.prod);
    });

    test('cannot be set on a disposed scope', () async {
      final scope = cobaltTestRoot();
      await scope.dispose();

      expect(
        () => scope.useEnvironment(CobaltEnvironment.prod),
        throwsA(isA<CobaltScopeStateError>()),
      );
    });
  });

  group('a manually built graph', () {
    test('selects an implementation the same way the generator does', () async {
      Future<String> noteStoreIn(CobaltEnvironment environment) async {
        final scope = cobaltTestRoot(name: 'app');
        if (environment.matches(const {'prod'})) {
          scope.registerSingleton<String>('sql');
        }
        if (environment.matches(const {'dev', 'test'})) {
          scope.registerSingleton<String>('fake');
        }
        await scope.init();
        final value = scope.get<String>();
        await scope.dispose();
        return value;
      }

      expect(await noteStoreIn(CobaltEnvironment.prod), 'sql');
      expect(await noteStoreIn(CobaltEnvironment.dev), 'fake');
      expect(await noteStoreIn(CobaltEnvironment.test), 'fake');
    });
  });
}
