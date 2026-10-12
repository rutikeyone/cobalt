import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

class _AppScope implements CobaltScopeBuilder {
  const _AppScope();

  @override
  void build(CobaltScope scope) {
    scope
      ..registerLazySingleton<Clock>(const ValueFactory(Clock()))
      ..registerLazySingleton<Api>(FnFactory((r) => Api(r.get<Clock>())));
  }
}

void main() {
  group('scopes', () {
    late CobaltScope leaked;

    test('cobaltTestScope starts the graph', () async {
      final scope = await cobaltTestScope(
        root: const _AppScope(),
        rootName: 'app',
      );
      leaked = scope;

      expect(scope.name, 'app');
      expect(scope.get<Api>().clock, isA<Clock>());
    });

    test('and disposed it when the previous test ended', () {
      expect(leaked.state, CobaltScopeState.disposed);
    });

    // Ticket carries a field on purpose: a const class is canonicalised, so
    // two `const Clock()` values are the same object and the assertion would
    // pass for the wrong reason.
    test('pushForTest shadows without touching the parent', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Ticket>(FnFactory((_) => Ticket('root')));
      final child = root.pushForTest()
        ..registerSingleton<Ticket>(Ticket('override'));

      expect(child.get<Ticket>().id, 'override');
      expect(root.get<Ticket>().id, 'root');
    });
  });

  group('openForTest', () {
    test('opens the builder under this scope, named after it', () async {
      final root = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Clock>(const ValueFactory(Clock()));

      final child = await root.openForTest(const _TicketScope('open'));

      expect(child.name, '_TicketScope');
      expect(child.state, CobaltScopeState.active);
      expect(child.get<Ticket>().id, 'open');
      expect(root.children, [child]);
    });

    test('takes a name and overrides', () async {
      final root = cobaltTestRoot();

      final child = await root.openForTest(
        const _TicketScope('real'),
        name: 'session',
        overrides: [CobaltOverride<Ticket>.value(Ticket('fake'))],
      );

      expect(child.name, 'session');
      expect(child.get<Ticket>().id, 'fake');
    });

    test('is disposed when the test ends', () async {
      final root = CobaltScope.root(name: 'app');
      late CobaltScope child;

      addTearDown(() async {
        expect(child.state, CobaltScopeState.disposed);
        await root.dispose();
      });

      child = await root.openForTest(const _TicketScope('open'));
    });
  });

  group('ownerOf', () {
    test('names the scope an override would have to beat', () {
      final root = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Clock>(const ValueFactory(Clock()))
        ..registerLazySingleton<Api>(FnFactory((r) => Api(r.get<Clock>())));
      final child = root.pushForTest()..registerSingleton<Clock>(const Clock());

      expect(
        child.ownerOf<Clock>(),
        same(child),
        reason: 'the override is here',
      );
      expect(
        child.ownerOf<Api>(),
        same(root),
        reason: 'Api is owned above, so it will not see the override',
      );
    });

    test('is null for something nothing registers', () {
      expect(cobaltTestRoot().ownerOf<Clock>(), isNull);
    });
  });

  group('DisposeRecorder', () {
    test('records teardown order, newest first', () async {
      final recorder = DisposeRecorder();
      final scope = CobaltScope.root()
        ..registerLazySingleton<Disposable>(recorder.factory('first'));
      scope.get<Disposable>();
      scope.adopt(recorder.value('second'));

      await scope.dispose();

      expect(recorder.entries, ['second', 'first']);
    });

    test('its log belongs to the recorder, not to the library', () {
      expect(DisposeRecorder().entries, isEmpty);
      expect(DisposeRecorder().entries, isEmpty);
    });
  });

  group('CapturingObserver', () {
    test('sees the events a graph emits', () async {
      final observer = CapturingObserver();
      final root = CobaltScope.root(name: 'app', observers: [observer]);
      root.push('child');

      expect(observer.saw(CobaltEventKind.scopePushed), isTrue);
      expect(observer.ofKind(CobaltEventKind.scopePushed), hasLength(1));

      await root.dispose();

      expect(observer.kinds, contains(CobaltEventKind.scopeDisposed));
    });
  });

  group('factories', () {
    test('ValueFactory stays lazy, unlike registerSingleton', () {
      const value = Clock();
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Clock>(const ValueFactory(value));

      expect(scope.keys, contains(const CobaltKey(Clock)));
      expect(scope.get<Clock>(), same(value));
    });

    test('FnFactory resolves from the scope it is given', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Clock>(const ValueFactory(Clock()))
        ..registerFactory<Api>(FnFactory((r) => Api(r.get<Clock>())));

      expect(scope.get<Api>().clock, same(scope.get<Clock>()));
    });
  });
}

class _TicketScope implements CobaltScopeBuilder {
  const _TicketScope(this.id);

  final String id;

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<Ticket>(FnFactory((_) => Ticket(id)));
}
