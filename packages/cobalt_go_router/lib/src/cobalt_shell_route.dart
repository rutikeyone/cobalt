import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_go_router/src/cobalt_route_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Builds the registrations a flow adds, from the route state that opened it.
typedef CobaltRouteScopeBuilder =
    CobaltScopeBuilder Function(GoRouterState state);

/// Reads what distinguishes one run of a flow from another.
///
/// Usually a path parameter. Returning a different value tears the flow's
/// scope down and builds a new one; returning the same value keeps it.
typedef CobaltRouteIdentity = Object? Function(GoRouterState state);

/// Produces replacements for what a flow registers, from the route state
/// that opened it — called each time the flow's scope is created.
typedef CobaltRouteOverrides =
    List<CobaltOverride<Object>> Function(GoRouterState state);

/// A [ShellRoute] whose subtree owns an Cobalt scope.
///
/// The scope is created when the flow is entered, survives every navigation
/// between [routes], and is disposed when navigation leaves the flow. That
/// falls out of how go_router keys a shell's page — by the identity of the
/// [ShellRoute] object — so the widget tree is the only owner and there is no
/// second source of truth about the flow's lifetime.
///
/// ```dart
/// CobaltShellRoute(
///   name: 'checkout',
///   identity: (state) => state.pathParameters['orderId'],
///   scope: (state) => CheckoutScope(state.pathParameters['orderId']!),
///   routes: [
///     GoRoute(path: '/orders/:orderId/summary', builder: (_, _) => const Summary()),
///     GoRoute(path: '/orders/:orderId/payment', builder: (_, _) => const Payment()),
///   ],
/// )
/// ```
///
/// Inside the flow nothing new applies: `context.cobalt<T>()` resolves from the
/// nearest scope, so the flow shadows the root for as long as it is open.
///
/// Being a class rather than a function, a flow can be given a name of its own
/// and reused:
///
/// ```dart
/// class CheckoutFlowRoute extends CobaltShellRoute {
///   CheckoutFlowRoute()
///     : super(name: 'checkout', scope: ..., routes: [...]);
/// }
/// ```
///
/// Construct it once, with the rest of the route table. A fresh instance is a
/// different flow as far as go_router is concerned, because the shell's page
/// key is the route object's identity.
///
/// Pass [shell] to wrap the flow in shared chrome — it receives the
/// flow-scoped child, so an app bar built there can resolve from the flow.
///
/// A flow whose routes are not one subtree cannot be expressed this way; see
/// this package's README for why that case is deliberately not covered.
class CobaltShellRoute extends ShellRoute {
  /// Declares a flow that owns a scope.
  CobaltShellRoute({
    required String name,
    required CobaltRouteScopeBuilder scope,
    required super.routes,
    CobaltRouteIdentity? identity,
    ShellRouteBuilder? shell,
    Widget? loading,
    Widget Function(BuildContext context, Object error)? errorBuilder,
    CobaltRouteOverrides? overrides,
    super.navigatorKey,
    super.observers,
    super.parentNavigatorKey,
    super.redirect,
    super.restorationScopeId,
    super.notifyRootObserver,
  }) : super(
         builder: (context, state, child) => CobaltRouteScope(
           name: name,
           identity: identity?.call(state),
           builder: scope(state),
           loading: loading,
           errorBuilder: errorBuilder,
           overrides: overrides == null ? null : () => overrides(state),
           child: shell == null ? child : shell(context, state, child),
         ),
       );
}

/// [CobaltShellRoute] as a function, for route tables written that way.
///
/// Identical in every respect — it builds the same object. Prefer the class:
/// it reads alongside `GoRoute` and `ShellRoute`, and it can be subclassed.
CobaltShellRoute cobaltShellRoute({
  required String name,
  required CobaltRouteScopeBuilder scope,
  required List<RouteBase> routes,
  CobaltRouteIdentity? identity,
  ShellRouteBuilder? shell,
  Widget? loading,
  Widget Function(BuildContext context, Object error)? errorBuilder,
  CobaltRouteOverrides? overrides,
  GlobalKey<NavigatorState>? navigatorKey,
  List<NavigatorObserver>? observers,
}) => CobaltShellRoute(
  name: name,
  scope: scope,
  routes: routes,
  identity: identity,
  shell: shell,
  loading: loading,
  errorBuilder: errorBuilder,
  overrides: overrides,
  navigatorKey: navigatorKey,
  observers: observers,
);
