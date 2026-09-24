import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

abstract interface class Api {
  List<String> get trail;
}

final class RealApi implements Api, Disposable {
  RealApi(this.recorder);

  final DisposeRecorder recorder;

  @override
  List<String> get trail => ['real'];

  @override
  void dispose() => recorder.record('real api');
}

final class FakeApi implements Api {
  @override
  List<String> get trail => ['fake'];
}

final class Wrapped implements Api {
  Wrapped(this.label, this.inner);

  final String label;
  final Api inner;

  @override
  List<String> get trail => [label, ...inner.trail];
}

final class Clock {
  const Clock(this.now);

  final int now;
}

final class Stamped implements Api {
  Stamped(this.inner, this.clock);

  final Api inner;
  final Clock clock;

  @override
  List<String> get trail => ['at ${clock.now}', ...inner.trail];
}

final class Label {
  Label(this.text);

  final String text;
}

FnDecorator<Api> wrapping(String label) =>
    FnDecorator((inner, _) => Wrapped(label, inner));

final class _Graph implements CobaltScopeBuilder {
  const _Graph(this.build_);

  final void Function(CobaltScope scope) build_;

  @override
  void build(CobaltScope scope) => build_(scope);
}

void main() {
  late DisposeRecorder recorder;

  setUp(() => recorder = DisposeRecorder());

  group('wrapping', () {
    test('a lazy singleton is decorated once and shared', () {
      var built = 0;
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Api>(
          FnFactory((_) {
            built++;
            return RealApi(recorder);
          }),
        )
        ..decorate<Api>(wrapping('logged'));

      final first = scope.get<Api>();

      expect(first.trail, ['logged', 'real']);
      expect(identical(first, scope.get<Api>()), isTrue);
      expect(built, 1);
    });

    test('the first decorator is innermost, the last outermost', () {
      final scope = cobaltTestRoot()
        ..decorate<Api>(wrapping('retried'))
        ..registerLazySingleton<Api>(FnFactory((_) => RealApi(recorder)))
        ..decorate<Api>(wrapping('logged'));

      expect(scope.get<Api>().trail, ['logged', 'retried', 'real']);
      expect(scope.debugDecoratorsOf(const CobaltKey(Api)), [
        FnDecorator<Api>,
        FnDecorator<Api>,
      ]);
    });

    test('a transient is decorated every time it is built', () {
      final scope = cobaltTestRoot()
        ..registerFactory<Api>(FnFactory((_) => FakeApi()))
        ..decorate<Api>(wrapping('logged'));

      final first = scope.get<Api>();
      final second = scope.get<Api>();

      expect(first.trail, ['logged', 'fake']);
      expect(identical(first, second), isFalse);
    });

    test('a parameterized registration is decorated per call', () {
      final scope = cobaltTestRoot()
        ..registerParamFactory<Label, String>(
          FnParamFactory((_, text) => Label(text)),
        )
        ..decorate<Label>(FnDecorator((inner, _) => Label('<${inner.text}>')));

      expect(scope.getWithParam<Label, String>('a').text, '<a>');
      expect(scope.getWithParam<Label, String>('b').text, '<b>');
    });

    test('an eager singleton decorated after it was registered', () {
      final scope = cobaltTestRoot()
        ..registerEagerSingleton<Api>(FnFactory((_) => RealApi(recorder)))
        ..decorate<Api>(wrapping('logged'));

      expect(scope.get<Api>().trail, ['logged', 'real']);
    });

    test(
      'an async singleton is decorated for the one that depends on it',
      () async {
        final scope = cobaltTestRoot()
          ..registerAsyncSingleton<Api>(
            AsyncFnFactory((_) async => RealApi(recorder)),
          )
          ..registerAsyncSingleton<Label>(
            AsyncFnFactory(
              (resolver) async => Label(resolver.get<Api>().trail.join(' ')),
            ),
            dependsOn: {const CobaltKey(Api)},
          )
          ..decorate<Api>(wrapping('logged'));

        await scope.init();

        expect(scope.get<Label>().text, 'logged real');
      },
    );

    test('a lazy async singleton is decorated once built', () async {
      final scope = cobaltTestRoot()
        ..registerLazyAsyncSingleton<Api>(
          AsyncFnFactory((_) async => RealApi(recorder)),
        )
        ..decorate<Api>(wrapping('logged'));

      final api = await scope.getAsync<Api>();

      expect(api.trail, ['logged', 'real']);
      expect(identical(api, scope.get<Api>()), isTrue);
    });

    test('an override is what gets decorated', () {
      final scope =
          cobaltTestRoot(overrides: [CobaltOverride<Api>.value(FakeApi())])
            ..registerLazySingleton<Api>(FnFactory((_) => RealApi(recorder)))
            ..decorate<Api>(wrapping('logged'));

      expect(scope.get<Api>().trail, ['logged', 'fake']);
    });

    test('a decorator resolves through the scope that owns the key', () {
      final scope = cobaltTestRoot()
        ..registerSingleton<Clock>(const Clock(7))
        ..registerLazySingleton<Api>(FnFactory((_) => FakeApi()))
        ..decorate<Api>(
          FnDecorator(
            (inner, resolver) => Stamped(inner, resolver.get<Clock>()),
          ),
        );

      expect(scope.pushForTest().get<Api>().trail, ['at 7', 'fake']);
    });

    test('decorating one named registration leaves its siblings alone', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Api>(FnFactory((_) => FakeApi()), name: 'a')
        ..registerLazySingleton<Api>(FnFactory((_) => FakeApi()), name: 'b')
        ..decorate<Api>(wrapping('logged'), name: 'a');

      expect(
        [for (final api in scope.getAll<Api>()) api.trail],
        [
          ['logged', 'fake'],
          ['fake'],
        ],
      );
    });
  });

  group('ownership', () {
    test(
      'the inner instance is closed once, the decorator not at all',
      () async {
        final scope = CobaltScope.root()
          ..registerLazySingleton<Api>(FnFactory((_) => RealApi(recorder)))
          ..decorate<Api>(wrapping('logged'));
        scope.get<Api>();

        await scope.dispose();

        expect(recorder.entries, ['real api']);
      },
    );
  });

  group('mistakes', () {
    test('a decorator resolving its own key is a cycle', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Api>(FnFactory((_) => FakeApi()))
        ..decorate<Api>(FnDecorator((inner, resolver) => resolver.get<Api>()));

      expect(() => scope.get<Api>(), throwsA(isA<CobaltCycleError>()));
    });

    test('decorating what was already resolved is refused', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Api>(FnFactory((_) => FakeApi()));
      scope.get<Api>();

      expect(
        () => scope.decorate<Api>(wrapping('late')),
        throwsA(
          isA<CobaltDecoratorError>().having(
            (e) => e.message,
            'message',
            contains('already resolved'),
          ),
        ),
      );
    });

    test('a decorator for a key an ancestor owns names the owner', () {
      final app = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Api>(FnFactory((_) => FakeApi()));
      final child = app.pushForTest('screen');

      expect(
        () => child.runBuilder(
          _Graph((scope) => scope.decorate<Api>(wrapping('logged'))),
        ),
        throwsA(
          isA<CobaltDecoratorError>().having((e) => e.owner, 'owner', 'app'),
        ),
      );
    });

    test('a decorator for a key nobody registers fails the builder', () {
      final scope = cobaltTestRoot();

      expect(
        () => scope.runBuilder(
          _Graph((scope) => scope.decorate<Api>(wrapping('logged'))),
        ),
        throwsA(
          isA<CobaltDecoratorError>().having((e) => e.owner, 'owner', isNull),
        ),
      );
    });
  });
}
