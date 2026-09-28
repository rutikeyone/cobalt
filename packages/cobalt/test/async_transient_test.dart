import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class Report implements Disposable {
  Report({this.source = 'real'});

  final String source;
  var isClosed = false;

  @override
  void dispose() => isClosed = true;
}

final class Store {
  Store(this.label);

  final String label;
}

final class Index {}

final class _Kinds extends CobaltObserver {
  final kinds = <CobaltRegistrationKind>[];

  @override
  void onInstanceCreated(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
  }) => kinds.add(kind);
}

const _deadlock = Duration(seconds: 2);

void main() {
  CobaltScope reports({List<CobaltObserver> observers = const []}) =>
      cobaltTestRoot(observers: observers)
        ..registerLazySingleton<Store>(FnFactory((_) => Store('root')))
        ..registerAsyncFactory<Report>(
          AsyncFnFactory((resolver) async {
            await Future<void>.delayed(Duration.zero);
            return Report(source: resolver.get<Store>().label);
          }),
        );

  group('building on every call', () {
    test('awaits the factory', () async {
      final report = await reports().getAsync<Report>();

      expect(report.source, 'root');
    });

    test('every call builds a new instance the scope does not keep', () async {
      final scope = reports();

      final first = await scope.getAsync<Report>();
      final again = await scope.getAsync<Report>();
      await scope.dispose();

      expect(first, isNot(same(again)));
      expect(first.isClosed, isFalse, reason: 'the caller owns it');
      expect(again.isClosed, isFalse, reason: 'the caller owns it');
    });

    test('concurrent calls do not share a build', () async {
      var builds = 0;
      final scope = cobaltTestRoot()
        ..registerAsyncFactory<Report>(
          AsyncFnFactory((_) async {
            builds++;
            await Future<void>.delayed(Duration.zero);
            return Report();
          }),
        );

      final both = await Future.wait([
        scope.getAsync<Report>(),
        scope.getAsync<Report>(),
      ]);

      expect(builds, 2);
      expect(both.first, isNot(same(both.last)));
    });

    test('runs on the scope that owns the registration', () async {
      final root = reports();
      final child = root.push('screen')
        ..registerLazySingleton<Store>(FnFactory((_) => Store('child')));

      final report = await child.getAsync<Report>();

      expect(report.source, 'root');
    });

    test('a factory can await a lazy registration', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Store>(
          AsyncFnFactory((_) async => Store('lazy')),
        )
        ..registerAsyncFactory<Report>(
          AsyncFnFactory(
            (resolver) async =>
                Report(source: (await resolver.getAsync<Store>()).label),
          ),
        );

      expect((await scope.getAsync<Report>()).source, 'lazy');
    });

    test('may be registered after init', () async {
      final scope = cobaltTestRoot();
      await scope.init();

      scope.registerAsyncFactory<Report>(AsyncFnFactory((_) async => Report()));

      expect(await scope.getAsync<Report>(), isA<Report>());
    });

    test('is not built by init', () async {
      var builds = 0;
      final scope = cobaltTestRoot()
        ..registerAsyncFactory<Report>(
          AsyncFnFactory((_) async {
            builds++;
            return Report();
          }),
        );

      await scope.init();

      expect(builds, 0);
    });

    test('getAllAsync builds one alongside the rest, in order', () async {
      final scope = cobaltTestRoot()
        ..registerSingleton<Report>(Report(source: 'eager'), name: 'a')
        ..registerAsyncFactory<Report>(
          AsyncFnFactory((_) async => Report(source: 'async')),
          name: 'b',
        );

      final all = await scope.getAllAsync<Report>();

      expect(all.map((r) => r.source), ['eager', 'async']);
    });
  });

  group('what it refuses', () {
    test('a synchronous resolve names getAsync', () {
      final scope = reports();

      expect(
        () => scope.get<Report>(),
        throwsA(
          isA<CobaltAsyncTransientError>()
              .having((e) => e.key, 'key', const CobaltKey(Report))
              .having((e) => e.message, 'message', contains('getAsync')),
        ),
      );
      expect(
        () => scope.getOrNull<Report>(),
        throwsA(isA<CobaltAsyncTransientError>()),
      );
      expect(
        () => scope.getAll<Report>(),
        throwsA(isA<CobaltAsyncTransientError>()),
      );
    });

    test('a synchronous resolve inside a build names the path', () {
      final scope = reports()
        ..registerLazySingleton<Index>(
          FnFactory((resolver) {
            resolver.get<Report>();
            return Index();
          }),
        );

      expect(
        () => scope.get<Index>(),
        throwsA(
          isA<CobaltAsyncTransientError>().having(
            (e) => e.resolving,
            'resolving',
            [const CobaltKey(Index)],
          ),
        ),
      );
    });

    test('a value it does not take', () {
      expect(
        reports().getAsyncWithParam<Report, int>(1),
        throwsA(isA<CobaltNotParameterizedError>()),
      );
    });

    test('a build that asks for its own key is a cycle, not a hang', () async {
      final scope = cobaltTestRoot()
        ..registerAsyncFactory<Report>(
          AsyncFnFactory((resolver) async {
            await Future<void>.delayed(Duration.zero);
            return resolver.getAsync<Report>();
          }),
        );

      await expectLater(
        scope.getAsync<Report>().timeout(_deadlock),
        throwsA(isA<CobaltCycleError>()),
      );
    });

    test('an async singleton cannot depend on it', () {
      final scope = reports()
        ..registerAsyncSingleton<Store>(
          AsyncFnFactory((_) async => Store('x')),
          name: 'late',
          dependsOn: {const CobaltKey(Report)},
        );

      expect(
        scope.init(),
        throwsA(
          isA<CobaltDependsOnError>().having(
            (e) => e.message,
            'message',
            contains('async factory'),
          ),
        ),
      );
    });

    test('warmUp has nothing to build ahead of time', () {
      expect(
        reports().warmUp(const [CobaltKey(Report)]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('beside the rest of the runtime', () {
    test('a synchronous transient override replaces it', () async {
      final scope = cobaltTestRoot(
        overrides: [
          CobaltOverride<Report>.transient(
            FnFactory((_) => Report(source: 'fake')),
          ),
        ],
      )..runBuilder(_ReportScope());

      expect((await scope.getAsync<Report>()).source, 'fake');
      expect(scope.overriddenKeys, [const CobaltKey(Report)]);
    });

    test('each build is decorated', () async {
      var wrapped = 0;
      final scope = reports()
        ..decorate<Report>(
          FnDecorator((inner, _) {
            wrapped++;
            return inner;
          }),
        );

      await scope.getAsync<Report>();
      await scope.getAsync<Report>();

      expect(wrapped, 2);
    });

    test('observers see the kind, not retained', () async {
      final kinds = _Kinds();
      final scope = reports(observers: [kinds]);

      await scope.getAsync<Report>();

      expect(kinds.kinds, contains(CobaltRegistrationKind.asyncTransient));
    });

    test('introspection names and builds it by key', () async {
      final scope = reports();
      const key = CobaltKey(Report);

      expect(scope.debugKindOf(key), CobaltRegistrationKind.asyncTransient);
      expect(await scope.debugResolveAsync(key), isA<Report>());
      expect(
        () => scope.debugResolve(key),
        throwsA(isA<CobaltAsyncTransientError>()),
      );
    });
  });
}

final class _ReportScope implements CobaltScopeBuilder {
  @override
  void build(CobaltScope scope) =>
      scope.registerAsyncFactory<Report>(AsyncFnFactory((_) async => Report()));
}
