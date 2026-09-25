import 'package:cobalt_go_router/src/cobalt_shell_route.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A [StatefulShellBranch] whose routes own a scope.
///
/// One tab, one scope. The branch's routes are wrapped in an [CobaltShellRoute],
/// so everything in the branch resolves from a scope of its own and the other
/// branches cannot see it.
///
/// ```dart
/// StatefulShellRoute.indexedStack(
///   builder: (_, _, shell) => Scaffold(body: shell, bottomNavigationBar: ...),
///   branches: [
///     CobaltStatefulShellBranch(
///       name: 'feed',
///       scope: (_) => const FeedScope(),
///       routes: [GoRoute(path: '/feed', builder: (_, _) => const FeedScreen())],
///     ),
///     CobaltStatefulShellBranch(
///       name: 'profile',
///       scope: (_) => const ProfileScope(),
///       routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
///     ),
///   ],
/// )
/// ```
///
/// **A branch is kept alive, not kept visible.** go_router preserves branch
/// navigators off-screen, so the scope is built the first time the tab is
/// visited (or at once when [preload] is set) and lives until the shell itself
/// is gone — it is *not* disposed when you switch away. That is the point of a
/// stateful shell: the tab keeps its state, and its dependencies are part of
/// that state. If a tab's dependencies must die when it is deselected, they do
/// not belong to the tab — give them a flow of their own inside it.
class CobaltStatefulShellBranch extends StatefulShellBranch {
  /// Declares a branch that owns a scope.
  CobaltStatefulShellBranch({
    required String name,
    required CobaltRouteScopeBuilder scope,
    required List<RouteBase> routes,
    CobaltRouteIdentity? identity,
    ShellRouteBuilder? shell,
    Widget? loading,
    Widget Function(BuildContext context, Object error)? errorBuilder,
    CobaltRouteOverrides? overrides,
    GlobalKey<NavigatorState>? branchNavigatorKey,
    super.initialLocation,
    super.restorationScopeId,
    super.observers,
    super.preload,
  }) : super(
         navigatorKey: branchNavigatorKey,
         routes: [
           CobaltShellRoute(
             name: name,
             scope: scope,
             routes: routes,
             identity: identity,
             shell: shell,
             loading: loading,
             errorBuilder: errorBuilder,
             overrides: overrides,
           ),
         ],
       );
}
