import 'package:flow_scopes/app/app_routes.dart';
import 'package:flow_scopes/features/cart/checkout_flow_route.dart';
import 'package:flow_scopes/features/diagnostics/ui/scope_tree_screen.dart';
import 'package:flow_scopes/features/home/ui/home_screen.dart';
import 'package:flow_scopes/features/orders/order_flow_route.dart';
import 'package:flow_scopes/features/workspace/workspace_shell_route.dart';
import 'package:go_router/go_router.dart';

/// The whole routing table.
///
/// [OrderFlowRoute] and [CheckoutFlowRoute] are the only things that are not
/// plain go_router, and both are ordinary `ShellRoute` subclasses — everything
/// inside one resolves from its flow's scope, and that scope is gone the moment
/// navigation leaves.
GoRouter buildAppRouter({String initialLocation = AppRoutes.home}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: AppRoutes.home, builder: (_, _) => const HomeScreen()),
    GoRoute(
      path: AppRoutes.scopeTree,
      builder: (_, _) => const ScopeTreeScreen(),
    ),
    OrderFlowRoute(),
    CheckoutFlowRoute(),
    WorkspaceShellRoute(),
  ],
);
