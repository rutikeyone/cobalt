import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:flutter/material.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support.dart';

void main() {
  late CobaltScope root;
  late GlobalKey<StatefulNavigationShellState> shellKey;

  setUp(() {
    recorder = DisposeRecorder();
    root = cobaltTestRoot(name: 'app');
    shellKey = GlobalKey<StatefulNavigationShellState>();
  });

  Future<void> start(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(app(root, router));
    await settle(tester);
    await settle(tester);
  }

  group('CobaltStatefulShellBranch', () {
    GoRouter branchRouter() => GoRouter(
      initialLocation: '/feed',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('out')),
        ),
        StatefulShellRoute.indexedStack(
          key: shellKey,
          builder: (_, _, shell) => shell,
          branches: [
            CobaltStatefulShellBranch(
              name: 'feed',
              scope: (_) => const TrackedScope('feed'),
              routes: [
                GoRoute(path: '/feed', builder: (_, _) => const Probe()),
              ],
            ),
            CobaltStatefulShellBranch(
              name: 'profile',
              scope: (_) => const TrackedScope('profile'),
              routes: [
                GoRoute(path: '/profile', builder: (_, _) => const Probe()),
              ],
            ),
          ],
        ),
      ],
    );

    testWidgets('each branch resolves from a scope of its own', (tester) async {
      await start(tester, branchRouter());
      expect(find.text('label:feed'), findsOneWidget);

      shellKey.currentState!.goBranch(1);
      await settle(tester);
      await settle(tester);

      expect(find.text('label:profile'), findsOneWidget);
    });

    testWidgets('a branch scope is built on first visit, not before', (
      tester,
    ) async {
      await start(tester, branchRouter());

      expect(root.children.map((s) => s.name), ['feed']);

      shellKey.currentState!.goBranch(1);
      await settle(tester);
      await settle(tester);

      expect(root.children.map((s) => s.name), ['feed', 'profile']);
    });

    testWidgets('switching away keeps the branch alive, by design', (
      tester,
    ) async {
      await start(tester, branchRouter());
      shellKey.currentState!.goBranch(1);
      await settle(tester);
      await settle(tester);

      expect(
        recorder.entries,
        isEmpty,
        reason:
            'branch navigators are preserved off-screen, so a branch scope is '
            'kept alive rather than kept visible',
      );
    });

    testWidgets('leaving the shell disposes every branch scope', (
      tester,
    ) async {
      final router = branchRouter();
      await start(tester, router);
      shellKey.currentState!.goBranch(1);
      await settle(tester);
      await settle(tester);
      expect(root.children, hasLength(2));

      router.go('/');
      await settle(tester);

      expect(root.children, isEmpty);
      expect(recorder.entries, containsAll(<String>['feed', 'profile']));
    });
  });

  group('CobaltStatefulShellRoute', () {
    testWidgets('the shell scope is the parent of every branch scope', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/w/feed',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('out')),
          ),
          CobaltStatefulShellRoute.indexedStack(
            key: shellKey,
            name: 'workspace',
            scope: (_) => const TrackedScope('workspace'),
            branches: [
              CobaltStatefulShellBranch(
                name: 'feed',
                scope: (_) => const TrackedScope('feed'),
                routes: [
                  GoRoute(
                    path: '/w/feed',
                    builder: (_, _) => const ScopeChain(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await start(tester, router);
      await settle(tester);

      expect(find.text('chain:feed<workspace<app'), findsOneWidget);
      expect(root.children.single.name, 'workspace');
      expect(root.children.single.children.single.name, 'feed');

      router.go('/');
      await settle(tester);

      expect(root.children, isEmpty);
    });

    /// The primary constructor, which mirrors `StatefulShellRoute.new` and
    /// takes the container builder itself. Only `.indexedStack` was exercised
    /// before, and tabs are the feature.
    testWidgets('the primary constructor owns a scope just the same', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/w/feed',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('out')),
          ),
          CobaltStatefulShellRoute(
            key: shellKey,
            name: 'workspace',
            scope: (_) => const TrackedScope('workspace'),
            navigatorContainerBuilder: (_, navigationShell, children) =>
                IndexedStack(
                  index: navigationShell.currentIndex,
                  children: children,
                ),
            branches: [
              CobaltStatefulShellBranch(
                name: 'feed',
                scope: (_) => const TrackedScope('feed'),
                routes: [
                  GoRoute(
                    path: '/w/feed',
                    builder: (_, _) => const ScopeChain(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await start(tester, router);
      await settle(tester);

      expect(find.text('chain:feed<workspace<app'), findsOneWidget);
      expect(root.children.single.name, 'workspace');

      router.go('/');
      await settle(tester);

      expect(
        root.children,
        isEmpty,
        reason:
            'the scope itself, not its teardown log: nobody resolved the '
            'workspace Tracked, so a lazy singleton was never built and there '
            'is nothing to have released',
      );
    });

    /// The primary constructor's `identity`, `overrides` and `shell` — each
    /// exercised above for `.indexedStack`, none yet for this one.
    testWidgets('the primary constructor takes identity, overrides and a shell '
        'too', (tester) async {
      // `:id` cannot be the branch's default route — go_router asserts every
      // branch has one unparameterized location to return to — so identity
      // comes from a query parameter instead, as a shell route's can.
      final router = GoRouter(
        initialLocation: '/w/feed?id=7',
        routes: [
          CobaltStatefulShellRoute(
            key: shellKey,
            name: 'workspace',
            identity: (state) => state.uri.queryParameters['id'],
            scope: (_) => const TrackedScope('workspace'),
            overrides: (_) => [
              CobaltOverride<Tracked>.value(Tracked('overridden')),
            ],
            shell: (_, _, navigationShell) => Column(
              children: [
                const Text('tabs'),
                Expanded(child: navigationShell),
              ],
            ),
            navigatorContainerBuilder: (_, navigationShell, children) =>
                IndexedStack(
                  index: navigationShell.currentIndex,
                  children: children,
                ),
            branches: [
              // Empty, so `Probe` resolves `Tracked` from the shell scope —
              // where `overrides` replaced it — rather than shadowing it with
              // a branch registration of its own.
              CobaltStatefulShellBranch(
                name: 'feed',
                scope: (_) => const _Empty(),
                routes: [
                  GoRoute(path: '/w/feed', builder: (_, _) => const Probe()),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await start(tester, router);

      expect(find.text('tabs'), findsOneWidget);
      expect(find.text('label:overridden'), findsOneWidget);
      expect(root.children.single.name, 'workspace:7');
    });

    /// `shell` is the wrapper the tab bar lives in; without it the shell route
    /// renders the navigation shell bare.
    testWidgets('the shell wrapper is rendered around the branches', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/w/feed',
        routes: [
          CobaltStatefulShellRoute.indexedStack(
            key: shellKey,
            name: 'workspace',
            scope: (_) => const TrackedScope('workspace'),
            shell: (_, _, navigationShell) => Column(
              children: [
                const Text('tabs'),
                Expanded(child: navigationShell),
              ],
            ),
            branches: [
              CobaltStatefulShellBranch(
                name: 'feed',
                scope: (_) => const TrackedScope('feed'),
                routes: [
                  GoRoute(
                    path: '/w/feed',
                    builder: (_, _) => const ScopeChain(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await start(tester, router);
      await settle(tester);

      expect(find.text('tabs'), findsOneWidget);
      expect(find.text('chain:feed<workspace<app'), findsOneWidget);
    });

    testWidgets(
      'identity names the shell scope, as it does for CobaltShellRoute',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/w/feed?id=7',
          routes: [
            CobaltStatefulShellRoute.indexedStack(
              key: shellKey,
              name: 'workspace',
              identity: (state) => state.uri.queryParameters['id'],
              scope: (_) => const TrackedScope('workspace'),
              branches: [
                CobaltStatefulShellBranch(
                  name: 'feed',
                  scope: (_) => const TrackedScope('feed'),
                  routes: [
                    GoRoute(path: '/w/feed', builder: (_, _) => const Probe()),
                  ],
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        await start(tester, router);

        expect(root.children.single.name, 'workspace:7');
      },
    );
  });
}

/// A branch that owns no scope of its own, so a type it does not register
/// resolves from whatever ancestor does.
class _Empty implements CobaltScopeBuilder {
  const _Empty();

  @override
  void build(CobaltScope scope) {}
}
