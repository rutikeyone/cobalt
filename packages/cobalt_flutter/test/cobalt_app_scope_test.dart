import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Marker implements Disposable {
  Marker(this.label, this._log);

  final String label;
  final List<String> _log;

  @override
  void dispose() => _log.add(label);
}

/// The log is per test, not global: teardown is not awaited, so a scope from
/// one test can finish releasing while the next one runs.
final class MarkerFactory implements CobaltFactory<Marker> {
  const MarkerFactory(this.label, this.log);

  final String label;
  final List<String> log;

  @override
  Marker create(CobaltResolver resolver) => Marker(label, log);
}

/// Renders what the graph resolved, so tests can compare instances.
class Probe extends StatelessWidget {
  const Probe({super.key});

  @override
  Widget build(BuildContext context) {
    final marker = context.cobalt<Marker>();
    return Text(
      '${marker.label}:${identityHashCode(marker)}',
      textDirection: TextDirection.ltr,
    );
  }
}

/// A child scope under the root, to prove a restart rebuilds the subtree.
class ChildScope implements CobaltScopeBuilder {
  const ChildScope();

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<String>(const _NameFactory());
}

final class _NameFactory implements CobaltFactory<String> {
  const _NameFactory();

  @override
  String create(CobaltResolver resolver) => resolver.get<Marker>().label;
}

/// Records the identity of every step instance that ever ran, which is how
/// the freshness test tells a re-run from a re-use.
class CountingStep implements CobaltBootstrapStep {
  CountingStep(this.ran);

  final List<int> ran;

  @override
  String get name => 'counting';

  @override
  void run() => ran.add(identityHashCode(this));
}

class RootBuilder implements CobaltScopeBuilder {
  const RootBuilder(this.label, this.log);

  final String label;
  final List<String> log;

  // Eager, so the instance exists as soon as the graph is built — a lazy one
  // nobody resolved would leave nothing to release.
  @override
  void build(CobaltScope scope) =>
      scope.registerSingleton<Marker>(MarkerFactory(label, log).create(scope));
}

void main() {
  late List<String> disposeLog;

  setUp(() => disposeLog = <String>[]);

  // Factories here are synchronous on purpose: these tests build the graph
  // inside testWidgets, where a real Future.delayed would never complete.
  Future<CobaltScope> startOk() => CobaltApplication.start(
    root: RootBuilder('root', disposeLog),
    rootName: 'app',
  );

  Future<CobaltScope> startBoom() async => throw StateError('startup failed');

  String rendered() =>
      (find.byType(Text).evaluate().first.widget as Text).data!;

  group('starting', () {
    testWidgets('shows loading until the graph is ready, then the child', (
      tester,
    ) async {
      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          rootName: 'app',
          loading: const Text('loading', textDirection: TextDirection.ltr),
          child: const Probe(),
        ),
      );

      expect(find.text('loading'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('loading'), findsNothing);
      expect(rendered(), startsWith('root:'));
    });
  });

  group('overrides', () {
    testWidgets('replace what the root registers, on every start', (
      tester,
    ) async {
      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          overrides: () => [
            CobaltOverride<Marker>.lazy(MarkerFactory('fake', disposeLog)),
          ],
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();
      expect(rendered(), startsWith('fake:'));

      final context = tester.element(find.byType(Probe));
      await CobaltAppScope.of(context).restart();
      await tester.pumpAndSettle();

      expect(rendered(), startsWith('fake:'));
    });

    testWidgets('a restart gets a fresh value, not the one just closed', (
      tester,
    ) async {
      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          overrides: () => [
            CobaltOverride<Marker>.value(Marker('fake', disposeLog)),
          ],
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();
      final first = rendered();

      await CobaltAppScope.of(tester.element(find.byType(Probe))).restart();
      await tester.pumpAndSettle();

      expect(rendered(), startsWith('fake:'));
      expect(
        rendered(),
        isNot(first),
        reason:
            'the first graph disposed its value; a stored list would hand the '
            'restart that same closed object',
      );
    });

    testWidgets('reach the graph through CobaltAppScope.builder too', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: CobaltAppScope.builder(
            root: RootBuilder('root', disposeLog),
            overrides: () => [
              CobaltOverride<Marker>.lazy(MarkerFactory('fake', disposeLog)),
            ],
          ),
          home: const Probe(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('fake:'), findsOneWidget);
    });
  });

  group('a failed start', () {
    testWidgets('reaches errorBuilder instead of killing the app', (
      tester,
    ) async {
      await tester.pumpWidget(
        CobaltAppScope.start(
          start: startBoom,
          errorBuilder: (context, error, retry) =>
              Text('failed: $error', textDirection: TextDirection.ltr),
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('startup failed'), findsOneWidget);
    });

    testWidgets('is rethrown in build when there is no errorBuilder', (
      tester,
    ) async {
      await tester.pumpWidget(
        CobaltAppScope.start(start: startBoom, child: const Probe()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('retry brings the graph up on the second attempt', (
      tester,
    ) async {
      var attempts = 0;
      Future<CobaltScope> flaky() async {
        attempts++;
        if (attempts == 1) throw StateError('not yet');
        return startOk();
      }

      await tester.pumpWidget(
        CobaltAppScope.start(
          start: flaky,
          errorBuilder: (context, error, retry) => GestureDetector(
            onTap: retry,
            child: const Text('retry', textDirection: TextDirection.ltr),
          ),
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('retry'), findsOneWidget);

      await tester.tap(find.text('retry'));
      await tester.pumpAndSettle();

      expect(rendered(), startsWith('root:'));
      expect(attempts, 2);
    });
  });

  group('unmounting', () {
    testWidgets('disposes the root it owned', (tester) async {
      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          rootName: 'app',
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();
      expect(disposeLog, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(disposeLog, ['root']);
    });

    testWidgets('releases a graph that finished starting too late', (
      tester,
    ) async {
      final gate = Completer<void>();
      Future<CobaltScope> slow() async {
        await gate.future;
        return startOk();
      }

      await tester.pumpWidget(
        CobaltAppScope.start(start: slow, child: const Probe()),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await tester.pumpAndSettle();

      expect(disposeLog, [
        'root',
      ], reason: 'a scope nobody is waiting for still has to be released');
    });
  });

  group('restart', () {
    testWidgets('disposes the old graph and builds a new one', (tester) async {
      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          rootName: 'app',
          loading: const Text('loading', textDirection: TextDirection.ltr),
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();
      final before = rendered();

      final controller = CobaltAppScope.of(tester.element(find.byType(Probe)));
      await controller.restart();
      await tester.pumpAndSettle();

      expect(disposeLog, ['root']);
      expect(rendered(), isNot(before));
    });

    testWidgets('rebuilds the subtree, so child scopes get the new root', (
      tester,
    ) async {
      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          rootName: 'app',
          child: const CobaltScopeWidget(
            name: 'child',
            builder: ChildScope(),
            child: _ChildProbe(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final firstRoot = _rootOf(tester);

      await CobaltAppScope.of(
        tester.element(find.byType(_ChildProbe)),
      ).restart();
      await tester.pumpAndSettle();

      expect(_rootOf(tester), isNot(same(firstRoot)));
      expect(
        _rootOf(tester).children.single.name,
        'child',
        reason: 'the child scope was rebuilt under the new root, not orphaned',
      );
    });
  });

  group('disposeOnExitRequest', () {
    testWidgets('is off by default, so nothing observes the exit', (
      tester,
    ) async {
      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          rootName: 'app',
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();

      expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit);
      expect(disposeLog, isEmpty);
    });

    testWidgets('when on, the graph is released before the app quits', (
      tester,
    ) async {
      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          rootName: 'app',
          disposeOnExitRequest: true,
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();

      final response = await tester.binding.handleRequestAppExit();

      expect(response, AppExitResponse.exit);
      expect(disposeLog, ['root']);
    });
  });

  group('the declarative form', () {
    testWidgets('builds the same graph CobaltAppScope.start would', (
      tester,
    ) async {
      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          rootName: 'app',
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();

      expect(rendered(), startsWith('root:'));
      expect(
        CobaltScopeProvider.of(tester.element(find.byType(Probe))).name,
        'app',
      );
    });

    testWidgets('asks bootstrap for fresh steps on every start', (
      tester,
    ) async {
      final ran = <int>[];

      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          bootstrap: () => [CountingStep(ran)],
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();

      await CobaltAppScope.of(tester.element(find.byType(Probe))).restart();
      await tester.pumpAndSettle();

      expect(ran, hasLength(2));
      expect(
        ran.first,
        isNot(ran.last),
        reason:
            'a restart must get new step instances — the released ones hold '
            'resources they already gave back',
      );
    });

    testWidgets('passes observers to the graph', (tester) async {
      final observer = RecordingObserver();

      await tester.pumpWidget(
        CobaltAppScope(
          root: RootBuilder('root', disposeLog),
          rootName: 'app',
          observers: [observer],
          child: const Probe(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(observer.disposed, ['app']);
    });
  });

  group('CobaltAppScope.builder', () {
    testWidgets('publishes the scope above the navigator, under the theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: CobaltAppScope.builder(
            root: RootBuilder('root', disposeLog),
            rootName: 'app',
            // A bare Scaffold, not a second MaterialApp: inside builder the
            // theme and directionality are already there.
            loading: const Scaffold(body: Text('loading')),
          ),
          home: const Probe(),
        ),
      );

      expect(find.text('loading'), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('loading'), findsNothing);
      expect(rendered(), startsWith('root:'));
      expect(
        find.byType(Navigator),
        findsWidgets,
        reason: 'the navigator is the child the builder wraps',
      );
    });

    testWidgets('refuses an app with no routing to wrap', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.shrink();
          },
        ),
      );

      final build = CobaltAppScope.builder(
        root: RootBuilder('root', disposeLog),
      );

      expect(() => build(context, null), throwsAssertionError);
    });
  });
}

/// Watches teardown rather than creation: [RootBuilder] registers an
/// already-built value, and `onInstanceCreated` only fires when the scope
/// itself constructs something.
final class RecordingObserver extends CobaltObserver {
  final disposed = <String>[];

  @override
  void onScopeDisposeStarted(CobaltScopeRef scope) => disposed.add(scope.name);
}

/// Climbs to the root: the probe sits below the child scope, so the nearest
/// provider is that child, not the root.
CobaltScope _rootOf(WidgetTester tester) =>
    CobaltScopeProvider.of(tester.element(find.byType(_ChildProbe))).root;

class _ChildProbe extends StatelessWidget {
  const _ChildProbe();

  @override
  Widget build(BuildContext context) =>
      Text(context.cobalt<String>(), textDirection: TextDirection.ltr);
}
