import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:flow_scopes/app/app_router.dart';
import 'package:flow_scopes/app/flow_scopes_app.dart';
import 'package:flow_scopes/core/event_log.dart';
import 'package:flow_scopes/core/flow_event.dart';
import 'package:cobalt_test_flutter/cobalt_test_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late CobaltScope app;
  late GoRouter router;

  setUp(() => router = buildAppRouter());

  tearDown(() => router.dispose());

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(FlowScopesApp(router: router));
    await settle(tester);
    await settle(tester);
    app = mountedRootScope(tester);
  }

  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester);
  }

  group('the flow owns its dependencies', () {
    testWidgets('opening a flow pushes a scope named after the order', (
      tester,
    ) async {
      await start(tester);
      await go(tester, '/orders/1/summary');

      expect(find.text('scope: order:1'), findsOneWidget);
      expect(app.children.single.name, 'order:1');
    });

    testWidgets('moving inside the flow keeps the same draft', (tester) async {
      await start(tester);
      await go(tester, '/orders/1/summary');
      await tester.tap(find.byKey(const Key('to-payment')));
      await settle(tester);

      expect(find.byKey(const Key('payment-draft')), findsOneWidget);
      expect(app.get<EventLog>().entries, [
        const FlowEvent(FlowEventKind.draftCreated, '1'),
      ]);
    });

    testWidgets('leaving the flow disposes the draft', (tester) async {
      await start(tester);
      await go(tester, '/orders/1/summary');
      await go(tester, '/');

      expect(app.get<EventLog>().entries, [
        const FlowEvent(FlowEventKind.draftCreated, '1'),
        const FlowEvent(FlowEventKind.draftDisposed, '1'),
      ]);
      expect(app.children, isEmpty);
    });

    testWidgets('switching order rebuilds the flow scope', (tester) async {
      await start(tester);
      await go(tester, '/orders/1/summary');
      await go(tester, '/orders/2/summary');

      expect(app.get<EventLog>().entries, [
        const FlowEvent(FlowEventKind.draftCreated, '1'),
        const FlowEvent(FlowEventKind.draftDisposed, '1'),
        const FlowEvent(FlowEventKind.draftCreated, '2'),
      ]);
      expect(app.children.single.name, 'order:2');
    });
  });

  group('a flow of top-level routes', () {
    testWidgets('cart, checkout and payment share one draft', (tester) async {
      await start(tester);
      await tester.tap(find.byKey(const Key('open-cart')));
      await settle(tester);
      expect(find.text('scope: cart'), findsOneWidget);
      final first = _draftLine(tester, 'cart');

      await tester.tap(find.byKey(const Key('cart-next')));
      await settle(tester);
      expect(_draftLine(tester, 'checkout'), first);

      await tester.tap(find.byKey(const Key('cart-next')));
      await settle(tester);
      expect(_draftLine(tester, 'payment'), first);

      expect(app.get<EventLog>().entries, [
        const FlowEvent(FlowEventKind.cartCreated, 'cart'),
      ]);
      expect(app.children.single.name, 'cart');
    });

    testWidgets('the URLs stay top-level', (tester) async {
      await start(tester);
      await go(tester, '/checkout');

      expect(router.routerDelegate.currentConfiguration.uri.path, '/checkout');
      expect(find.text('/checkout'), findsOneWidget);
    });

    testWidgets('leaving from the last screen disposes the draft', (
      tester,
    ) async {
      await start(tester);
      await go(tester, '/payment');
      await tester.tap(find.byKey(const Key('cart-leave')));
      await settle(tester);

      expect(app.get<EventLog>().entries, [
        const FlowEvent(FlowEventKind.cartCreated, 'cart'),
        const FlowEvent(FlowEventKind.cartDisposed, 'cart'),
      ]);
      expect(app.children, isEmpty);

      await settle(tester);
      expect(find.text('cart draft disposed'), findsOneWidget);
    });
  });

  group('the tabbed workspace', () {
    testWidgets('the shell and the first tab each build a scope', (
      tester,
    ) async {
      await start(tester);
      await go(tester, '/workspace/feed');
      await settle(tester);

      expect(find.text('shell scope: workspace'), findsOneWidget);
      expect(app.get<EventLog>().entries, [
        const FlowEvent(FlowEventKind.scopeBuilt, 'workspace'),
        const FlowEvent(FlowEventKind.scopeBuilt, 'feed'),
      ]);
      expect(app.children.single.name, 'workspace');
      expect(app.children.single.children.single.name, 'feed');
    });

    testWidgets('switching tabs adds a scope and disposes nothing', (
      tester,
    ) async {
      await start(tester);
      await go(tester, '/workspace/feed');
      await settle(tester);

      await tester.tap(find.byKey(const Key('tab-profile')));
      await settle(tester);
      await settle(tester);

      expect(app.get<EventLog>().entries, [
        const FlowEvent(FlowEventKind.scopeBuilt, 'workspace'),
        const FlowEvent(FlowEventKind.scopeBuilt, 'feed'),
        const FlowEvent(FlowEventKind.scopeBuilt, 'profile'),
      ]);
      expect(app.children.single.children.map((s) => s.name), [
        'feed',
        'profile',
      ]);
    });

    testWidgets('leaving the workspace disposes all three scopes', (
      tester,
    ) async {
      await start(tester);
      await go(tester, '/workspace/feed');
      await settle(tester);
      await go(tester, '/');

      expect(
        app.get<EventLog>().entries,
        containsAll(<FlowEvent>[
          const FlowEvent(FlowEventKind.scopeDisposed, 'feed'),
          const FlowEvent(FlowEventKind.scopeDisposed, 'workspace'),
        ]),
      );
      expect(app.children, isEmpty);
    });
  });

  group('the scope tree screen', () {
    testWidgets('shows only the root once the flow is closed', (tester) async {
      await start(tester);
      await go(tester, '/orders/1/summary');
      await go(tester, '/');
      await go(tester, '/scope-tree');

      expect(find.byKey(const Key('scope-app')), findsOneWidget);
      expect(find.byKey(const Key('scope-order:1')), findsNothing);
    });
  });
}

String _draftLine(WidgetTester tester, String step) {
  final tile = tester.widget<ListTile>(find.byKey(Key('cart-draft-$step')));
  return (tile.subtitle! as Text).data!;
}
