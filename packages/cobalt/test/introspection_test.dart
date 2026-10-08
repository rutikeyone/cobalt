import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  setUp(resetLogs);

  group('getOrNull', () {
    test('returns the instance when something is registered', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(scope.getOrNull<Logger>(), same(scope.get<Logger>()));
    });

    test('returns null instead of throwing when nothing is', () {
      expect(cobaltTestRoot().getOrNull<Logger>(), isNull);
    });

    test('a name that nothing registers reads as absent', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(scope.getOrNull<Logger>(name: 'audit'), isNull);
      expect(scope.getOrNull<Logger>(), isNotNull);
    });

    test('resolves through ancestors like get does', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());
      final child = root.push('child');

      expect(child.getOrNull<Logger>(), same(root.get<Logger>()));
    });

    test('an async singleton asked for too early still throws', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<SlowService>(const SlowFactory('db', 5));

      expect(
        () => scope.getOrNull<SlowService>(),
        throwsA(isA<CobaltNotReadyError>()),
        reason: 'registered but not ready is not the same fact as absent',
      );

      await scope.init();
      expect(scope.getOrNull<SlowService>(), isNotNull);
    });

    test('a parameterized factory still throws', () {
      final scope = cobaltTestRoot()
        ..registerParamFactory<Greeting, String>(const GreetingFactory());

      expect(() => scope.getOrNull<Greeting>(), throwsA(isA<CobaltError>()));
    });
  });

  group('keys', () {
    test('lists what the scope registers, in registration order', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory())
        ..registerLazySingleton<ApiClient>(const ApiClientFactory());

      expect(scope.keys.map((key) => key.type).toList(), [Logger, ApiClient]);
    });

    test('keeps named registrations apart from unnamed ones', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory())
        ..registerLazySingleton<Logger>(const LoggerFactory(), name: 'audit');

      expect(scope.keys, hasLength(2));
      expect(scope.keys, contains(const CobaltKey(Logger, name: 'audit')));
    });

    test('lists a lazy singleton nobody resolved', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(scope.keys, contains(const CobaltKey(Logger)));
      expect(recorder.entries, isEmpty, reason: 'nothing was built');
    });

    test('does not list what only adopt owns', () {
      final scope = cobaltTestRoot()..adopt(Recorder('adopted'));

      expect(scope.keys, isEmpty);
    });

    test('is empty after dispose rather than a tombstone', () async {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());
      await scope.dispose();

      expect(scope.keys, isEmpty);
    });

    test('is unmodifiable', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(
        () => scope.keys.add(const CobaltKey(ApiClient)),
        throwsUnsupportedError,
      );
    });
  });

  group('visibleKeys', () {
    test('includes what ancestors register', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());
      final child = root.push('child')
        ..registerLazySingleton<ApiClient>(const ApiClientFactory());

      expect(child.visibleKeys.keys.map((key) => key.type), [
        ApiClient,
        Logger,
      ]);
    });

    test('names the scope that owns each key', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());
      final child = root.push('child')
        ..registerLazySingleton<ApiClient>(const ApiClientFactory());

      expect(child.visibleKeys[const CobaltKey(Logger)], same(root));
      expect(child.visibleKeys[const CobaltKey(ApiClient)], same(child));
    });

    test('a child shadowing an ancestor owns the key', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());
      final child = root.push('child')
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(child.visibleKeys[const CobaltKey(Logger)], same(child));
      expect(root.visibleKeys[const CobaltKey(Logger)], same(root));
    });
  });

  group('root and the tree', () {
    test('root climbs to the outermost scope', () {
      final root = cobaltTestRoot(name: 'app');
      final grandchild = root.push('session').push('flow');

      expect(grandchild.root, same(root));
      expect(root.root, same(root));
    });

    test('describeTree indents children under their parent', () {
      final root = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Logger>(const LoggerFactory());
      root.push('session');

      final lines = root.describeTree().split('\n');

      expect(lines, hasLength(2));
      expect(lines.first, startsWith('app  [open]  1 registration'));
      expect(lines.last, startsWith('  session'));
    });
  });

  test('diagnostics still answer on a disposed scope', () async {
    final root = cobaltTestRoot(name: 'app');
    final child = root.push('child');
    await child.dispose();

    expect(child.state, CobaltScopeState.disposed);
    expect(child.keys, isEmpty);
    expect(child.describeTree(), contains('disposed'));
    expect(child.root, same(root));
  });
}
