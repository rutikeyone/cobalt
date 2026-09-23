import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:flow_scopes/features/cart/cart_flow_scope.dart';
import 'package:flow_scopes/features/cart/cart_step.dart';
import 'package:flow_scopes/features/cart/ui/cart_step_screen.dart';
import 'package:go_router/go_router.dart';

/// A flow made of top-level routes, with no path of its own.
///
/// A `ShellRoute` has no `path`, so the children below keep the URLs they
/// declare — `/cart`, `/checkout`, `/payment` — and still share one scope for
/// as long as the user is on any of them.
class CheckoutFlowRoute extends CobaltShellRoute {
  CheckoutFlowRoute()
    : super(
        name: 'cart',
        scope: (_) => const CartFlowScope(),
        routes: [
          for (final step in CartStep.values)
            GoRoute(
              path: step.path,
              builder: (_, _) => CartStepScreen(step: step),
            ),
        ],
      );
}
