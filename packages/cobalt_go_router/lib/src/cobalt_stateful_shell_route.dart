import 'package:cobalt_go_router/src/cobalt_shell_route.dart';
import 'package:cobalt_go_router/src/cobalt_route_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// A [StatefulShellRoute] whose whole tabbed shell owns a scope.
///
/// Use it when every tab needs the same thing and that thing should die with
/// the shell — a signed-in area, an editor, anything whose tabs are views of
/// one session. The scope sits above every branch navigator, so all branches
/// resolve from it, and each branch may still add a scope of its own with
/// [CobaltStatefulShellBranch].
///
/// ```dart
/// CobaltStatefulShellRoute.indexedStack(
///   name: 'workspace',
///   scope: (state) => WorkspaceScope(state.pathParameters['id']!),
///   identity: (state) => state.pathParameters['id'],
///   shell: (_, _, navigationShell) => Scaffold(
///     body: navigationShell,
///     bottomNavigationBar: TabBar(navigationShell: navigationShell),
///   ),
///   branches: [...],
/// )
/// ```
///
/// The lifetime is the shell's: created when the shell is entered, disposed
/// when navigation leaves it. Switching branches does not touch it — see
/// [CobaltStatefulShellBranch] for why a branch is kept alive rather than kept
/// visible.
class CobaltStatefulShellRoute extends StatefulShellRoute {
  /// Declares a stateful shell that owns a scope, with a container of your
  /// own. Mirrors [StatefulShellRoute.new].
  CobaltStatefulShellRoute({
    required String name,
    required CobaltRouteScopeBuilder scope,
    required super.branches,
    required super.navigatorContainerBuilder,
    CobaltRouteIdentity? identity,
    StatefulShellRouteBuilder? shell,
    Widget? loading,
    Widget Function(BuildContext context, Object error)? errorBuilder,
    CobaltRouteOverrides? overrides,
    super.parentNavigatorKey,
    super.redirect,
    super.restorationScopeId,
    super.notifyRootObserver,
    super.key,
  }) : super(
         builder: (context, state, navigationShell) => CobaltRouteScope(
           name: name,
           identity: identity?.call(state),
           builder: scope(state),
           loading: loading,
           errorBuilder: errorBuilder,
           overrides: overrides == null ? null : () => overrides(state),
           child: shell == null
               ? navigationShell
               : shell(context, state, navigationShell),
         ),
       );

  /// Declares a stateful shell that owns a scope, using an `IndexedStack` for
  /// its branch navigators. Mirrors [StatefulShellRoute.indexedStack].
  CobaltStatefulShellRoute.indexedStack({
    required String name,
    required CobaltRouteScopeBuilder scope,
    required super.branches,
    CobaltRouteIdentity? identity,
    StatefulShellRouteBuilder? shell,
    Widget? loading,
    Widget Function(BuildContext context, Object error)? errorBuilder,
    CobaltRouteOverrides? overrides,
    super.parentNavigatorKey,
    super.redirect,
    super.restorationScopeId,
    super.notifyRootObserver,
    super.key,
  }) : super.indexedStack(
         builder: (context, state, navigationShell) => CobaltRouteScope(
           name: name,
           identity: identity?.call(state),
           builder: scope(state),
           loading: loading,
           errorBuilder: errorBuilder,
           overrides: overrides == null ? null : () => overrides(state),
           child: shell == null
               ? navigationShell
               : shell(context, state, navigationShell),
         ),
       );
}
