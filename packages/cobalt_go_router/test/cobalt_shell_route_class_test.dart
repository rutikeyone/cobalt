import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:flutter/material.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support.dart';

/// A flow given a name of its own — the reason [CobaltShellRoute] is a class.
class OrderFlowRoute extends CobaltShellRoute {
  OrderFlowRoute()
    : super(
        name: 'order',
        identity: (state) => state.pathParameters['id'],
        scope: (state) => TrackedScope('order-${state.pathParameters['id']}'),
        routes: [
          GoRoute(
            path: '/orders/:id/summary',
            builder: (_, _) => const Probe(),
          ),
          GoRoute(
            path: '/orders/:id/payment',
            builder: (_, _) => const Probe(),
          ),
        ],
      );
}

GoRouter routerWith(RouteBase flow) => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('home')),
    ),
    flow,
  ],
);

void main() {
  late CobaltScope root;

  setUp(() {
    recorder = DisposeRecorder();
    root = cobaltTestRoot(name: 'app');
  });

  Future<void> run(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(app(root, router));
    await settle(tester);
    router.go('/orders/7/summary');
    await settle(tester);
  }

  group('CobaltShellRoute', () {
    testWidgets('is a ShellRoute, so it drops into any route table', (
      tester,
    ) async {
      final flow = CobaltShellRoute(
        name: 'order',
        scope: (_) => const TrackedScope('order'),
        routes: [
          GoRoute(
            path: '/orders/:id/summary',
            builder: (_, _) => const Probe(),
          ),
        ],
      );

      expect(flow, isA<ShellRoute>());
      expect(flow, isA<RouteBase>());

      await run(tester, routerWith(flow));

      expect(find.text('scope:order'), findsOneWidget);
      expect(root.children.single.name, 'order');
    });

    testWidgets('subclassing gives a flow a name of its own', (tester) async {
      await run(tester, routerWith(OrderFlowRoute()));

      expect(find.text('label:order-7'), findsOneWidget);
      expect(root.children.single.name, 'order:7');
    });

    testWidgets('shell wraps the child the branches render into', (
      tester,
    ) async {
      final flow = CobaltShellRoute(
        name: 'order',
        scope: (_) => const TrackedScope('order'),
        shell: (_, _, child) => Column(
          children: [
            const Text('chrome'),
            Expanded(child: child),
          ],
        ),
        routes: [
          GoRoute(
            path: '/orders/:id/summary',
            builder: (_, _) => const Probe(),
          ),
        ],
      );

      await run(tester, routerWith(flow));

      expect(find.text('chrome'), findsOneWidget);
      expect(find.text('scope:order'), findsOneWidget);
    });

    testWidgets('without shell the branches render bare', (tester) async {
      final flow = CobaltShellRoute(
        name: 'order',
        scope: (_) => const TrackedScope('order'),
        routes: [
          GoRoute(
            path: '/orders/:id/summary',
            builder: (_, _) => const Probe(),
          ),
        ],
      );

      await run(tester, routerWith(flow));

      expect(find.text('chrome'), findsNothing);
    });

    testWidgets('a subclass keeps identity and teardown', (tester) async {
      final router = routerWith(OrderFlowRoute());
      await run(tester, router);

      router.go('/orders/8/summary');
      await settle(tester);
      expect(recorder.entries, ['order-7']);
      expect(root.children.single.name, 'order:8');

      router.go('/');
      await settle(tester);
      expect(recorder.entries, ['order-7', 'order-8']);
      expect(root.children, isEmpty);
    });
  });

  group('the function spelling', () {
    testWidgets('builds the very same type', (tester) async {
      final built = cobaltShellRoute(
        name: 'order',
        scope: (_) => const TrackedScope('order'),
        routes: [
          GoRoute(
            path: '/orders/:id/summary',
            builder: (_, _) => const Probe(),
          ),
        ],
      );

      expect(built, isA<CobaltShellRoute>());

      await run(tester, routerWith(built));

      expect(find.text('scope:order'), findsOneWidget);
    });
  });
}
