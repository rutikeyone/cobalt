import 'dart:io';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

abstract interface class Api {}

final class RealApi implements Api {}

final class Clock {
  const Clock();
}

final class Cart {}

final class _Graph implements CobaltScopeBuilder {
  const _Graph(this.build_);

  final void Function(CobaltScope scope) build_;

  @override
  void build(CobaltScope scope) => build_(scope);
}

CobaltDecorator<Api> _named(String label) => FnDecorator((inner, _) => inner);

void main() {
  group('describeGraph', () {
    test('lists each scope, its keys sorted, with kind and markers', () {
      var built = 0;
      final app =
          cobaltTestRoot(
            name: 'app',
            overrides: [CobaltOverride<Clock>.value(const Clock())],
          )..runBuilder(
            _Graph(
              (scope) => scope
                ..registerLazySingleton<Api>(
                  FnFactory((_) {
                    built++;
                    return RealApi();
                  }),
                )
                ..registerSingleton<Clock>(const Clock())
                ..registerFactory<Api>(FnFactory((_) => RealApi()), name: 'cdn')
                ..decorate<Api>(_named('Retrying'), debugLabel: 'Retrying')
                ..decorateAll<Api>(_named('Logging'), debugLabel: 'Logging'),
            ),
          );
      app
          .pushForTest('session')
          .registerLazySingleton<Cart>(FnFactory((_) => Cart()));

      expect(describeGraph(app), '''
scope "app"
  Api — lazySingleton, decorated: Retrying → Logging
  Api(cdn) — transient, decorated: Logging
  Clock — singleton, overridden
  scope "session"
    Cart — lazySingleton
''');
      expect(built, 0, reason: 'describing a graph builds nothing');
    });

    test('shows the hooks each scope adds, above its keys', () {
      final app = cobaltTestRoot(name: 'app')
        ..hookAll<Api>(FnHook((_, _) {}), debugLabel: 'Audit')
        ..registerLazySingleton<Api>(FnFactory((_) => RealApi()));
      app.push('session').hookAll<Object>(const _NoHook<Object>());

      expect(describeGraph(app), '''
scope "app"
  hooks: Audit on Api
  Api — lazySingleton
  scope "session"
    hooks: _NoHook<Object> on Object
''');
    });

    test('an async registration is described without init', () {
      final app = cobaltTestRoot(name: 'app')
        ..registerAsyncSingleton<Clock>(
          AsyncFnFactory((_) async => const Clock()),
        )
        ..registerAsyncFactory<Cart>(AsyncFnFactory((_) async => Cart()));

      expect(describeGraph(app), '''
scope "app"
  Cart — asyncTransient
  Clock — asyncSingleton
''');
    });
  });

  group('expectGraphSnapshot', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('cobalt_snapshot'));
    tearDown(() => dir.deleteSync(recursive: true));

    CobaltScope graph({bool withCart = false}) {
      final app = cobaltTestRoot(name: 'app')
        ..registerSingleton<Clock>(const Clock());
      if (withCart) app.registerLazySingleton<Cart>(FnFactory((_) => Cart()));
      return app;
    }

    test('update writes the snapshot, and then it matches', () {
      final path = '${dir.path}/nested/graph.snapshot';

      expectGraphSnapshot(graph(), path, update: true);

      expect(File(path).readAsStringSync(), describeGraph(graph()));
      expectGraphSnapshot(graph(), path);
    });

    test('a change fails with a diff and how to accept it', () {
      final path = '${dir.path}/graph.snapshot';
      expectGraphSnapshot(graph(), path, update: true);

      expect(
        () => expectGraphSnapshot(graph(withCart: true), path),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('+   Cart — lazySingleton'),
              contains('    Clock — singleton'),
              contains('COBALT_UPDATE_SNAPSHOTS=1'),
            ),
          ),
        ),
      );
    });

    test('a missing snapshot fails and writes nothing', () {
      final path = '${dir.path}/missing.snapshot';

      expect(
        () => expectGraphSnapshot(graph(), path),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('No graph snapshot'), contains('Clock — singleton')),
          ),
        ),
      );
      expect(File(path).existsSync(), isFalse);
    });
  });

  group('expectGraphSnapshots', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('cobalt_snapshots'));
    tearDown(() => dir.deleteSync(recursive: true));

    final environments = {CobaltEnvironment.dev, CobaltEnvironment.prod};

    /// The graph for [environment]; with [drift], prod gains a registration.
    CobaltScope graphFor(CobaltEnvironment environment, {bool drift = false}) {
      final app = cobaltTestRoot(name: 'app')
        ..registerSingleton<Clock>(const Clock());
      if (environment == CobaltEnvironment.dev) {
        app.registerLazySingleton<Api>(FnFactory((_) => RealApi()));
      }
      if (drift && environment == CobaltEnvironment.prod) {
        app.registerLazySingleton<Cart>(FnFactory((_) => Cart()));
      }
      return app;
    }

    test('writes one file per environment, then each matches', () async {
      await expectGraphSnapshots(
        graphFor,
        environments: environments,
        directory: dir.path,
        update: true,
      );

      expect(
        File('${dir.path}/dev.txt').readAsStringSync(),
        contains('Api — lazySingleton'),
      );
      expect(
        File('${dir.path}/prod.txt').readAsStringSync(),
        isNot(contains('Api')),
      );
      await expectGraphSnapshots(
        graphFor,
        environments: environments,
        directory: dir.path,
      );
    });

    test(
      'names each environment that moved, having checked them all',
      () async {
        await expectGraphSnapshots(
          graphFor,
          environments: environments,
          directory: dir.path,
          update: true,
        );

        await expectLater(
          expectGraphSnapshots(
            (environment) => graphFor(environment, drift: true),
            environments: environments,
            directory: dir.path,
          ),
          throwsA(
            isA<TestFailure>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('environment "prod"'),
                contains('+   Cart — lazySingleton'),
                isNot(contains('environment "dev"')),
              ),
            ),
          ),
        );
      },
    );
  });

  group('describeGraphMermaid', () {
    test('draws scopes as nested subgraphs, facts under each key', () {
      final app = cobaltTestRoot(name: 'app')
        ..hookAll<Api>(FnHook((_, _) {}), debugLabel: 'Audit')
        ..registerLazySingleton<Api>(FnFactory((_) => RealApi()))
        ..decorate<Api>(_named('Logging'), debugLabel: 'Logging')
        ..registerLazySingleton<List<String>>(FnFactory((_) => []));
      app.push('session');

      expect(describeGraphMermaid(app), '''
flowchart TD
  subgraph s0["scope #quot;app#quot;"]
    direction TB
    s0_hooks(["hooks: Audit on Api"])
    s0_k0["Api<br/>lazySingleton<br/>decorated: Logging"]
    s0_k1["List#lt;String#gt;<br/>lazySingleton"]
    subgraph s1["scope #quot;session#quot;"]
      direction TB
      s1_empty["nothing registered"]
    end
  end
''');
    });

    test('says what describeGraph says', () {
      final app = cobaltTestRoot(
        name: 'app',
        overrides: [CobaltOverride<Clock>.value(const Clock())],
      )..registerLazySingleton<Clock>(FnFactory((_) => const Clock()));

      expect(describeGraph(app), contains('Clock — singleton, overridden'));
      expect(
        describeGraphMermaid(app),
        contains('Clock<br/>singleton<br/>overridden'),
      );
    });
  });
}

final class _NoHook<T extends Object> extends CobaltHook<T> {
  const _NoHook();

  @override
  void onBuilt(T instance, CobaltResolver resolver) {}
}
