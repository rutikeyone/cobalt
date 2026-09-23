import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

abstract interface class GreetingStore {
  String get greeting;
}

final class RealStore implements GreetingStore {
  @override
  String get greeting => 'real';
}

final class FakeStore implements GreetingStore {
  const FakeStore(this.greeting);

  @override
  final String greeting;
}

final class Greeter {
  Greeter(this.store);

  final GreetingStore store;

  String greet() => store.greeting;
}

final class Database {
  Database(this.label);

  final String label;
}

final class SearchIndex {
  SearchIndex(this.database);

  final Database database;
}

final class Closeable implements Disposable {
  Closeable(this.label, this.recorder);

  final String label;
  final DisposeRecorder recorder;

  @override
  void dispose() => recorder.record(label);
}

final class Editor {
  Editor(this.id);

  final int id;
}

final class _Step implements CobaltBootstrapStep, Disposable {
  _Step(this.recorder);

  final DisposeRecorder recorder;

  @override
  String get name => 'step';

  @override
  void run() {}

  @override
  void dispose() => recorder.record('step');
}

final class _Graph implements CobaltScopeBuilder {
  const _Graph(this.build_);

  final void Function(CobaltScope scope) build_;

  @override
  void build(CobaltScope scope) => build_(scope);
}

void main() {
  late DisposeRecorder recorder;

  setUp(() => recorder = DisposeRecorder());

  group('replacing a registration', () {
    test('a value replaces a lazy singleton whose factory never runs', () {
      var built = 0;
      final scope = cobaltTestRoot(
        overrides: [CobaltOverride<GreetingStore>.value(const FakeStore('x'))],
      );
      scope.registerLazySingleton<GreetingStore>(
        FnFactory((_) {
          built++;
          return RealStore();
        }),
      );

      expect(scope.get<GreetingStore>().greeting, 'x');
      expect(built, 0);
    });

    test('an override on the owner reaches the consumer registered there', () {
      final scope = cobaltTestRoot(
        overrides: [
          CobaltOverride<GreetingStore>.value(const FakeStore('hello')),
        ],
      );
      scope
        ..registerLazySingleton<GreetingStore>(FnFactory((_) => RealStore()))
        ..registerLazySingleton<Greeter>(
          FnFactory((resolver) => Greeter(resolver.get<GreetingStore>())),
        );

      expect(
        scope.pushForTest().get<Greeter>().greet(),
        'hello',
        reason:
            'shadowing from a child cannot do this: the factory of Greeter '
            'runs on the scope that owns it',
      );
    });

    test('an overridden eager singleton is never built', () {
      var built = 0;
      final scope = cobaltTestRoot(
        overrides: [CobaltOverride<GreetingStore>.value(const FakeStore('x'))],
      );
      scope.registerEagerSingleton<GreetingStore>(
        FnFactory((_) {
          built++;
          return RealStore();
        }),
      );

      expect(scope.get<GreetingStore>().greeting, 'x');
      expect(built, 0);
    });

    test('a value handed to registerSingleton is skipped yet still closed', () {
      final scope = CobaltScope.root(
        overrides: [
          CobaltOverride<Closeable>.value(Closeable('fake', recorder)),
        ],
      );
      final real = Closeable('real', recorder);
      scope.registerSingleton<Closeable>(real);

      expect(scope.get<Closeable>().label, 'fake');
      return scope.dispose().then((_) {
        expect(recorder.entries, containsAll(['fake', 'real']));
      });
    });

    test('a transient override builds on every resolution', () {
      final scope = cobaltTestRoot(
        overrides: [
          CobaltOverride<Database>.transient(FnFactory((_) => Database('t'))),
        ],
      )..registerLazySingleton<Database>(FnFactory((_) => Database('real')));

      final first = scope.get<Database>();
      expect(first.label, 't');
      expect(identical(first, scope.get<Database>()), isFalse);
    });

    test('a lazy override builds once', () {
      var built = 0;
      final scope = cobaltTestRoot(
        overrides: [
          CobaltOverride<Database>.lazy(
            FnFactory((_) {
              built++;
              return Database('lazy');
            }),
          ),
        ],
      )..registerFactory<Database>(FnFactory((_) => Database('real')));

      scope
        ..get<Database>()
        ..get<Database>();
      expect(built, 1);
    });

    test('a parameterized override is resolved through getWithParam', () {
      final scope =
          cobaltTestRoot(
            overrides: [
              CobaltParamOverride<Editor, int>(
                FnParamFactory((_, id) => Editor(id * 10)),
              ),
            ],
          )..registerParamFactory<Editor, int>(
            FnParamFactory((_, id) => Editor(id)),
          );

      expect(scope.getWithParam<Editor, int>(4).id, 40);
    });

    test('replacing one named registration leaves its siblings alone', () {
      final scope =
          cobaltTestRoot(
              overrides: [
                CobaltOverride<Database>.value(Database('fake'), name: 'a'),
              ],
            )
            ..registerLazySingleton<Database>(
              FnFactory((_) => Database('real a')),
              name: 'a',
            )
            ..registerLazySingleton<Database>(
              FnFactory((_) => Database('real b')),
              name: 'b',
            );

      expect(
        [for (final database in scope.getAll<Database>()) database.label],
        ['fake', 'real b'],
      );
    });
  });

  group('async registrations', () {
    test(
      'a value replaces an async singleton and satisfies dependsOn',
      () async {
        final scope = cobaltTestRoot(
          overrides: [CobaltOverride<Database>.value(Database('fake'))],
        );
        scope
          ..registerAsyncSingleton<Database>(
            AsyncFnFactory((_) async => Database('real')),
          )
          ..registerAsyncSingleton<SearchIndex>(
            AsyncFnFactory(
              (resolver) async => SearchIndex(resolver.get<Database>()),
            ),
            dependsOn: {const CobaltKey(Database)},
          );

        await scope.init();

        expect(scope.get<SearchIndex>().database.label, 'fake');
      },
    );

    test(
      'a lazy async build that awaits an overridden key gets the double',
      () async {
        final scope = cobaltTestRoot(
          overrides: [CobaltOverride<Database>.value(Database('fake'))],
        );
        scope
          ..registerLazyAsyncSingleton<Database>(
            AsyncFnFactory((_) async => Database('real')),
          )
          ..registerLazyAsyncSingleton<SearchIndex>(
            AsyncFnFactory(
              (resolver) async =>
                  SearchIndex(await resolver.getAsync<Database>()),
            ),
          );

        final index = await scope.getAsync<SearchIndex>();

        expect(index.database.label, 'fake');
      },
    );
  });

  group('mistakes', () {
    test('two overrides of one key are a duplicate', () {
      expect(
        () => CobaltScope.root(
          overrides: [
            CobaltOverride<Database>.value(Database('a')),
            CobaltOverride<Database>.value(Database('b')),
          ],
        ),
        throwsA(isA<CobaltDuplicateRegistrationError>()),
      );
    });

    test('registering an overridden key twice is still a duplicate', () {
      final scope = cobaltTestRoot(
        overrides: [CobaltOverride<Database>.value(Database('fake'))],
      )..registerFactory<Database>(FnFactory((_) => Database('one')));

      expect(
        () =>
            scope.registerFactory<Database>(FnFactory((_) => Database('two'))),
        throwsA(isA<CobaltDuplicateRegistrationError>()),
      );
    });

    test('an override without a type argument is refused at once', () {
      expect(
        () => CobaltScope.root(
          overrides: [CobaltOverride.value(const FakeStore('x'))],
        ),
        throwsA(
          isA<CobaltOverrideError>()
              .having((e) => e.key, 'key', const CobaltKey(Object))
              .having((e) => e.message, 'message', contains('inferred')),
        ),
        reason: 'inside the list the type argument is inferred as Object',
      );
    });

    test('an override nothing claims fails the builder, naming the fix', () {
      const inferred = CobaltOverride.value(FakeStore('x'));
      final scope = cobaltTestRoot(overrides: [inferred]);

      expect(
        () => scope.runBuilder(
          _Graph(
            (scope) => scope.registerLazySingleton<GreetingStore>(
              FnFactory((_) => RealStore()),
            ),
          ),
        ),
        throwsA(
          isA<CobaltOverrideError>()
              .having((e) => e.key, 'key', const CobaltKey(FakeStore))
              .having((e) => e.owner, 'owner', isNull)
              .having(
                (e) => e.message,
                'message',
                contains('CobaltOverride<Base>'),
              ),
        ),
      );
    });

    test('an override of a key an ancestor owns names the owner', () {
      final app = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<GreetingStore>(FnFactory((_) => RealStore()));
      final child = app.pushForTest('screen', [
        CobaltOverride<GreetingStore>.value(const FakeStore('x')),
      ]);

      expect(
        () => child.runBuilder(_Graph((_) {})),
        throwsA(
          isA<CobaltOverrideError>()
              .having((e) => e.owner, 'owner', 'app')
              .having((e) => e.message, 'message', contains('Move the')),
        ),
      );
    });

    test('a push refused for its overrides leaves no child behind', () {
      final root = cobaltTestRoot();

      expect(
        () => root.push(
          'screen',
          overrides: [
            CobaltOverride<Closeable>.value(Closeable('kept', recorder)),
            CobaltOverride.value(Database('untyped')),
          ],
        ),
        throwsA(isA<CobaltOverrideError>()),
      );
      expect(root.children, isEmpty);
    });

    test(
      'startup that fails on an override releases what it adopted',
      () async {
        await expectLater(
          CobaltApplication.start(
            root: _Graph((_) {}),
            bootstrap: [_Step(recorder)],
            overrides: [
              CobaltOverride<Closeable>.value(Closeable('override', recorder)),
            ],
          ),
          throwsA(isA<CobaltOverrideError>()),
        );

        expect(
          recorder.entries,
          ['step', 'override'],
          reason:
              'a value override was built by the caller before startup began, '
              'so it is owned before the step is adopted and closed after it',
        );
      },
    );

    test('startup that fails in init releases what it adopted', () async {
      await expectLater(
        CobaltApplication.start(
          root: _Graph(
            (scope) => scope.registerAsyncSingleton<Database>(
              AsyncFnFactory((_) async => throw StateError('no database')),
            ),
          ),
          bootstrap: [_Step(recorder)],
        ),
        throwsA(isA<StateError>()),
      );

      expect(recorder.entries, ['step']);
    });

    test('startup fails when an override replaces nothing', () {
      expect(
        () => CobaltApplication.start(
          root: _Graph((_) {}),
          overrides: [CobaltOverride<Database>.value(Database('fake'))],
        ),
        throwsA(isA<CobaltOverrideError>()),
      );
    });
  });

  group('being seen', () {
    test('observers are told, and the scope lists the key', () {
      final observer = CapturingObserver();
      final scope = cobaltTestRoot(
        name: 'app',
        observers: [observer],
        overrides: [CobaltOverride<Database>.value(Database('fake'))],
      );
      expect(observer.saw(CobaltEventKind.registrationOverridden), isFalse);

      scope.registerLazySingleton<Database>(FnFactory((_) => Database('real')));

      final events = observer.ofKind(CobaltEventKind.registrationOverridden);
      expect(events.single.key, const CobaltKey(Database));
      expect(events.single.level, CobaltLogLevel.info);
      expect(scope.overriddenKeys, {const CobaltKey(Database)});
    });

    test('an override is torn down in creation order with the rest', () async {
      final scope = CobaltScope.root(
        overrides: [
          CobaltOverride<Closeable>.lazy(
            FnFactory((_) => Closeable('fake', recorder)),
          ),
        ],
      )..registerLazySingleton<Database>(FnFactory((_) => Database('db')));
      scope.registerLazySingleton<Closeable>(
        FnFactory((_) => Closeable('real', recorder)),
      );
      final other = Closeable('built later', recorder);
      scope
        ..get<Closeable>()
        ..adopt(other);

      await scope.dispose();

      expect(recorder.entries, ['built later', 'fake']);
    });
  });

  group('registerEagerSingleton', () {
    test('builds now, and is reported like any other creation', () {
      final observer = CapturingObserver();
      var built = 0;
      final scope = cobaltTestRoot(observers: [observer])
        ..registerEagerSingleton<Database>(
          FnFactory((_) {
            built++;
            return Database('eager');
          }),
        );

      expect(built, 1);
      expect(
        scope.debugKindOf(const CobaltKey(Database)),
        CobaltRegistrationKind.singleton,
      );
      final created = observer.ofKind(CobaltEventKind.instanceCreated).single;
      expect(created.registrationKind, CobaltRegistrationKind.singleton);
      expect(created.retained, isTrue);
    });

    test('a factory that fails leaves nothing registered', () {
      final scope = cobaltTestRoot();

      expect(
        () => scope.registerEagerSingleton<Database>(
          FnFactory((resolver) => Database(resolver.get<Editor>().toString())),
        ),
        throwsA(isA<CobaltNotRegisteredError>()),
      );
      expect(scope.isRegistered<Database>(), isFalse);
    });

    test('what it builds is closed with the scope', () async {
      final scope = CobaltScope.root()
        ..registerEagerSingleton<Closeable>(
          FnFactory((_) => Closeable('eager', recorder)),
        );

      await scope.dispose();

      expect(recorder.entries, ['eager']);
    });
  });
}
