import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test_flutter/cobalt_test_flutter.dart';
import 'package:flow_scopes/app/app_scope.dart';
import 'package:flow_scopes/core/event_log.dart';
import 'package:flow_scopes/core/flow_event.dart';
import 'package:flow_scopes/features/orders/order_flow_scope.dart';
import 'package:flow_scopes/features/orders/ui/order_flow_chrome.dart';
import 'package:flow_scopes/features/orders/ui/order_payment_screen.dart';
import 'package:flow_scopes/features/orders/ui/order_summary_screen.dart';
import 'package:flow_scopes/l10n/flow_scopes_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final orderFlow = ShellRoute(
  builder: (context, state, child) {
    final orderId = state.pathParameters['orderId']!;
    return CobaltScopeWidget(
      key: ValueKey(orderId),
      name: 'order:$orderId',
      builder: OrderFlowScope(orderId),
      child: OrderFlowChrome(child: child),
    );
  },
  routes: [
    GoRoute(
      path: '/orders/:orderId/summary',
      builder: (_, state) =>
          OrderSummaryScreen(orderId: state.pathParameters['orderId']!),
    ),
    GoRoute(
      path: '/orders/:orderId/payment',
      builder: (_, state) =>
          OrderPaymentScreen(orderId: state.pathParameters['orderId']!),
    ),
  ],
);

void main() {
  late CobaltScope app;
  late GoRouter router;

  setUp(() {
    app = CobaltScope.root(name: 'app')..runBuilder(const AppScope());
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        orderFlow,
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    await app.dispose();
  });

  Future<void> start(WidgetTester tester) => tester.pumpWidget(
    MaterialApp.router(
      localizationsDelegates: FlowScopesL10n.localizationsDelegates,
      supportedLocales: FlowScopesL10n.supportedLocales,
      routerConfig: router,
      builder: (context, child) =>
          CobaltScopeProvider(scope: app, child: child!),
    ),
  );

  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester);
  }

  List<FlowEvent> events() => app.get<EventLog>().entries;

  testWidgets('entering the flow opens its scope', (tester) async {
    await start(tester);
    await go(tester, '/orders/1/summary');

    expect(find.text('scope: order:1'), findsOneWidget);
    expect(app.children.single.name, 'order:1');
  });

  testWidgets('moving inside the flow keeps its scope', (tester) async {
    await start(tester);
    await go(tester, '/orders/1/summary');
    await go(tester, '/orders/1/payment');

    expect(find.text('scope: order:1'), findsOneWidget);
    expect(events(), [const FlowEvent(FlowEventKind.draftCreated, '1')]);
  });

  testWidgets('another order is another scope', (tester) async {
    await start(tester);
    await go(tester, '/orders/1/summary');
    await go(tester, '/orders/2/summary');

    expect(find.text('scope: order:2'), findsOneWidget);
    expect(app.children.single.name, 'order:2');
    expect(
      events(),
      containsAll([
        const FlowEvent(FlowEventKind.draftDisposed, '1'),
        const FlowEvent(FlowEventKind.draftCreated, '2'),
      ]),
    );
  });

  testWidgets('leaving the flow closes its scope', (tester) async {
    await start(tester);
    await go(tester, '/orders/1/summary');
    await go(tester, '/');

    expect(app.children, isEmpty);
    expect(events().last, const FlowEvent(FlowEventKind.draftDisposed, '1'));
  });
}
