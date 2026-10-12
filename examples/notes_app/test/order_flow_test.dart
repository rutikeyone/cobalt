import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test_flutter/cobalt_test_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/core/event_log.dart';
import 'package:notes_app/features/order_flow/order_flow_route.dart';

void main() {
  late GoRouter router;

  setUp(
    () => router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        OrderFlowRoute(),
      ],
    ),
  );

  tearDown(() => router.dispose());

  Future<CobaltScope> start(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: CobaltAppScope.builder(root: const CobaltRoot()),
      ),
    );
    await settle(tester);
    return mountedRootScope(tester);
  }

  Future<void> go(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester);
  }

  testWidgets('the generated scope lives while the flow does', (tester) async {
    final app = await start(tester);

    await go(tester, '/orders/7');
    expect(find.text('order 7'), findsOneWidget);
    expect(app.children.single.name, 'order:7');

    await go(tester, '/');
    expect(app.children, isEmpty);
    expect(
      app.get<EventLog>().entries.where((entry) => entry.startsWith('order')),
      ['order 7 opened', 'order 7 closed'],
    );
  });
}
