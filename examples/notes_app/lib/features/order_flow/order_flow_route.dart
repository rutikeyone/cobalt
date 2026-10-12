import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/features/order_flow/order_note.dart';

class OrderFlowRoute extends CobaltShellRoute {
  OrderFlowRoute()
    : super(
        name: 'order',
        identity: _orderId,
        scope: (state) => OrderFlowScope(_orderId(state)),
        routes: [
          GoRoute(
            path: '/orders/:orderId',
            builder: (_, _) => const OrderNoteText(),
          ),
        ],
      );

  static String _orderId(GoRouterState state) =>
      state.pathParameters['orderId']!;
}

class OrderNoteText extends StatelessWidget {
  const OrderNoteText({super.key});

  @override
  Widget build(BuildContext context) =>
      Text('order ${context.cobalt<OrderNote>().orderId}');
}
