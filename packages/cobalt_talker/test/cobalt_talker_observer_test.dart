import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:cobalt_talker/cobalt_talker.dart';
import 'package:talker/talker.dart';
import 'package:test/test.dart';

class Marker implements Disposable {
  @override
  void dispose() {}
}

void main() {
  late Talker talker;

  setUp(() => talker = Talker());

  List<String> titles() => [for (final d in talker.history) d.title ?? ''];
  List<String?> messages() => [for (final d in talker.history) d.message];

  group('CobaltTalkerObserver', () {
    test('files each kind of event under its own title', () async {
      final root = cobaltTestRoot(
        name: 'app',
        observers: [CobaltTalkerObserver(talker)],
      );
      root.push('session');
      await root.dispose();

      expect(titles(), contains('cobalt-scope'));
      expect(
        messages().join('\n'),
        allOf(contains('scope "app/session" pushed'), contains('disposing')),
      );
    });

    test('an override replacing a registration is filed as a scope event', () {
      cobaltTestRoot(
        name: 'app',
        observers: [CobaltTalkerObserver(talker)],
        overrides: [CobaltOverride<Marker>.value(Marker())],
      ).registerLazySingleton<Marker>(FnFactory((_) => Marker()));

      expect(titles(), ['cobalt-scope']);
      expect(messages().single, contains('replaced by an override'));
    });

    test('stays quiet about instances unless asked', () {
      final root = cobaltTestRoot(
        name: 'app',
        observers: [CobaltTalkerObserver(talker)],
      )..registerLazySingleton<Marker>(FnFactory((_) => Marker()));

      root.get<Marker>();

      expect(titles(), isNot(contains('cobalt-instance')));
    });

    test('reports every instance in verbose mode', () {
      final root = cobaltTestRoot(
        name: 'app',
        observers: [CobaltTalkerObserver(talker, verbose: true)],
      )..registerLazySingleton<Marker>(FnFactory((_) => Marker()));

      root.get<Marker>();

      expect(titles(), contains('cobalt-instance'));
      expect(messages().join('\n'), contains('built Marker in "app"'));
    });

    test('a teardown failure becomes an cobalt-failure entry', () async {
      final root = cobaltTestRoot(
        name: 'app',
        observers: [CobaltTalkerObserver(talker)],
      )..registerSingleton<_Angry>(_Angry());

      await expectLater(root.dispose(), throwsA(isA<CobaltDisposeError>()));

      expect(titles(), contains('cobalt-failure'));
      final failure = talker.history.firstWhere(
        (d) => d.title == 'cobalt-failure',
      );
      expect(failure.exception, isA<StateError>());
      expect(failure.logLevel, LogLevel.warning);
    });

    test('startup milestones carry the step names', () async {
      await cobaltTestScope(
        root: const _MarkerScope(),
        bootstrap: [_Step('platform')],
        rootName: 'app',
        observers: [CobaltTalkerObserver(talker)],
      );

      expect(titles(), contains('cobalt-startup'));
      expect(
        messages().join('\n'),
        allOf(
          contains('bootstrap "platform" started'),
          contains('bootstrap "platform" done'),
        ),
      );
    });
  });

  /// Coverage found these five mappings unexercised, three of them the failure
  /// paths — in an adapter that exists so failures are visible.
  group('the paths you need when something breaks', () {
    test(
      'a failing async initializer becomes an cobalt-failure entry',
      () async {
        await expectLater(
          cobaltTestScope(
            root: const _ExplodingScope(),
            rootName: 'app',
            observers: [CobaltTalkerObserver(talker)],
          ),
          throwsA(isA<StateError>()),
        );

        final failure = talker.history.firstWhere(
          (entry) => entry.title == 'cobalt-failure',
        );
        expect(failure.message, contains('failed to initialize'));
        expect(failure.exception, isA<StateError>());
        expect(failure.logLevel, LogLevel.error);
      },
    );

    test('a failing bootstrap step names the step', () async {
      await expectLater(
        cobaltTestScope(
          root: const _MarkerScope(),
          bootstrap: [_Exploding('platform')],
          rootName: 'app',
          observers: [CobaltTalkerObserver(talker)],
        ),
        throwsA(isA<CobaltBootstrapError>()),
      );

      final failure = talker.history.firstWhere(
        (entry) => entry.title == 'cobalt-failure',
      );
      expect(failure.message, 'bootstrap "platform" failed');
      expect(failure.logLevel, LogLevel.error);
    });

    /// The event phase 3 added to replace a swallowed `catch (_)`: a step that
    /// ran, then could not be released while a later failure rolled startup
    /// back. Reported as a warning — the headline is the step that failed.
    test(
      'a step that cannot be released while rolling back is reported',
      () async {
        await expectLater(
          cobaltTestScope(
            root: const _MarkerScope(),
            bootstrap: [_Stubborn('platform'), _Exploding('config')],
            rootName: 'app',
            observers: [CobaltTalkerObserver(talker)],
          ),
          throwsA(isA<CobaltBootstrapError>()),
        );

        final messages = [for (final entry in talker.history) entry.message];
        expect(
          messages.join('\n'),
          allOf(
            contains('bootstrap "config" failed'),
            contains('bootstrap "platform" could not be released'),
          ),
        );
        final release = talker.history.firstWhere(
          (entry) => entry.message?.contains('could not be released') ?? false,
        );
        expect(release.logLevel, LogLevel.warning);
      },
    );
  });

  group('startup that succeeds', () {
    test(
      'reports the levels it is about to run and how long it took',
      () async {
        final scope = await cobaltTestScope(
          root: const _AsyncScope(),
          rootName: 'app',
          observers: [CobaltTalkerObserver(talker)],
        );
        expect(scope.state, CobaltScopeState.active);

        expect(
          messages().join('\n'),
          allOf(
            contains('scope "app" initializing, 1 level(s)'),
            contains('scope "app" ready in'),
          ),
        );
      },
    );

    test('a transient is marked loose, because the scope does not keep it', () {
      final root = cobaltTestRoot(
        name: 'app',
        observers: [CobaltTalkerObserver(talker, verbose: true)],
      )..registerFactory<Marker>(FnFactory((_) => Marker()));

      root.get<Marker>();

      expect(
        messages().join('\n'),
        contains('built Marker in "app" as transient (loose)'),
      );
    });
  });
}

final class _MarkerScope implements CobaltScopeBuilder {
  const _MarkerScope();

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<Marker>(FnFactory((_) => Marker()));
}

class _Step implements CobaltBootstrapStep {
  _Step(this.name);

  @override
  final String name;

  @override
  void run() {}
}

class _Angry implements Disposable {
  @override
  void dispose() => throw StateError('no');
}

final class _AsyncScope implements CobaltScopeBuilder {
  const _AsyncScope();

  @override
  void build(CobaltScope scope) => scope.registerAsyncSingleton<Marker>(
    AsyncFnFactory((_) async => Marker()),
  );
}

final class _ExplodingScope implements CobaltScopeBuilder {
  const _ExplodingScope();

  @override
  void build(CobaltScope scope) => scope.registerAsyncSingleton<Marker>(
    AsyncFnFactory((_) async => throw StateError('no')),
  );
}

class _Exploding implements CobaltBootstrapStep {
  _Exploding(this.name);

  @override
  final String name;

  @override
  void run() => throw StateError('no');
}

/// Runs, then refuses to be released.
class _Stubborn implements CobaltBootstrapStep, Disposable {
  _Stubborn(this.name);

  @override
  final String name;

  @override
  void run() {}

  @override
  void dispose() => throw StateError('no');
}
