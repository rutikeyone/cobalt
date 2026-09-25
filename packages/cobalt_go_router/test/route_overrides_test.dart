import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support.dart';

List<CobaltOverride<Object>> doubleFor(GoRouterState state) => [
  CobaltOverride<Tracked>.value(
    Tracked('double:${state.pathParameters['id'] ?? '-'}'),
  ),
];

void main() {
  late CobaltScope root;

  setUp(() {
    recorder = DisposeRecorder();
    root = cobaltTestRoot(name: 'app');
  });

  Future<void> start(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(app(root, router));
    await settle(tester);
    await settle(tester);
  }

  testWidgets('CobaltRouteScope hands its overrides to the scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      CobaltScopeProvider(
        scope: root,
        child: MaterialApp(
          home: CobaltRouteScope(
            name: 'flow',
            builder: const TrackedScope('real'),
            overrides: () => [CobaltOverride<Tracked>.value(Tracked('double'))],
            child: const Probe(),
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('label:double'), findsOneWidget);
  });

  testWidgets('CobaltShellRoute builds them from the route state', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/orders/7',
      routes: [
        CobaltShellRoute(
          name: 'order',
          identity: (state) => state.pathParameters['id'],
          scope: (_) => const TrackedScope('real'),
          overrides: doubleFor,
          routes: [
            GoRoute(path: '/orders/:id', builder: (_, _) => const Probe()),
          ],
        ),
      ],
    );
    addTearDown(() => router.dispose());

    await start(tester, router);
    expect(find.text('label:double:7'), findsOneWidget);

    router.go('/orders/8');
    await settle(tester);
    await settle(tester);
    expect(
      find.text('label:double:8'),
      findsOneWidget,
      reason: 'a new run of the flow asks for its overrides again',
    );
  });

  testWidgets('the function form passes them on too', (tester) async {
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        cobaltShellRoute(
          name: 'flow',
          scope: (_) => const TrackedScope('real'),
          overrides: doubleFor,
          routes: [GoRoute(path: '/a', builder: (_, _) => const Probe())],
        ),
      ],
    );
    addTearDown(() => router.dispose());

    await start(tester, router);
    expect(find.text('label:double:-'), findsOneWidget);
  });

  testWidgets('a stateful shell and its branches take them', (tester) async {
    final router = GoRouter(
      initialLocation: '/tabs/feed',
      routes: [
        CobaltStatefulShellRoute.indexedStack(
          name: 'tabs',
          scope: (_) => const TrackedScope('shell'),
          overrides: doubleFor,
          branches: [
            CobaltStatefulShellBranch(
              name: 'feed',
              scope: (_) => const _Empty(),
              routes: [
                GoRoute(path: '/tabs/feed', builder: (_, _) => const Probe()),
              ],
            ),
            CobaltStatefulShellBranch(
              name: 'profile',
              scope: (_) => const TrackedScope('branch'),
              overrides: (_) => [
                CobaltOverride<Tracked>.value(Tracked('branch double')),
              ],
              initialLocation: '/tabs/profile',
              routes: [
                GoRoute(
                  path: '/tabs/profile',
                  builder: (_, _) => const Probe(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(() => router.dispose());

    await start(tester, router);
    expect(find.text('label:double:-'), findsOneWidget);

    router.go('/tabs/profile');
    await settle(tester);
    await settle(tester);
    expect(find.text('label:branch double'), findsOneWidget);
  });
}

class _Empty implements CobaltScopeBuilder {
  const _Empty();

  @override
  void build(CobaltScope scope) {}
}
