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
}
