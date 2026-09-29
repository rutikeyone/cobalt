import 'package:flow_scopes/app/app_router.dart';
import 'package:flow_scopes/app/app_routes.dart';
import 'package:flow_scopes/app/app_scope.dart';
import 'package:flutter/material.dart';
import 'package:gallery/catalog/example_host.dart';
import 'package:go_router/go_router.dart';

/// Mounts `flow_scopes` — router and all — inside one gallery route.
///
/// The other examples hand over a screen; this one is *about* navigation, so
/// it brings its own routing table. A nested [Router] is what makes that
/// possible without the gallery adopting go_router everywhere: `GoRouter` is a
/// `RouterConfig`, so it drops straight in.
///
/// The back button needs saying out loud. A nested router only receives the
/// system back press if it is given a dispatcher of its own, so where there is
/// a parent [Router] this takes a child dispatcher and holds priority. The
/// gallery is Navigator-based, so usually there is none: on Android the
/// hardware back then leaves the example rather than stepping out of the flow.
/// Navigation *inside* the flow is unaffected — that comes from go_router's
/// own navigator, which is the part this example is about.
///
/// [initialLocation] and [visits] are for screenshots: the flow opens at that
/// location, then goes to each of [visits] in turn, a moment apart — the
/// taps a reader would make, made for them.
class FlowScopesHost extends StatefulWidget {
  const FlowScopesHost({
    this.initialLocation = AppRoutes.home,
    this.visits = const [],
    super.key,
  });

  final String initialLocation;
  final List<String> visits;

  @override
  State<FlowScopesHost> createState() => _FlowScopesHostState();
}

class _FlowScopesHostState extends State<FlowScopesHost> {
  late final GoRouter _router = buildAppRouter(
    initialLocation: widget.initialLocation,
  );

  ChildBackButtonDispatcher? _backButton;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _backButton = Router.maybeOf(
      context,
    )?.backButtonDispatcher?.createChildBackButtonDispatcher()?..takePriority();
  }

  @override
  void dispose() {
    final backButton = _backButton;
    if (backButton != null) backButton.parent.forget(backButton);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExampleHost(
    root: const AppScope(),
    rootName: 'app',
    // Spelled out rather than Router.withConfig, which takes the dispatcher
    // from the config and gives no way to substitute the child one.
    child: _Visits(
      router: _router,
      visits: widget.visits,
      child: Router<Object>(
        routeInformationProvider: _router.routeInformationProvider,
        routeInformationParser: _router.routeInformationParser,
        routerDelegate: _router.routerDelegate,
        backButtonDispatcher: _backButton,
        restorationScopeId: 'flow-scopes',
      ),
    ),
  );
}

/// Walks [router] through [visits], once the flow is on screen.
///
/// It sits inside the host so it starts only after the app scope is up: a
/// `go` made while the host still shows its spinner lands on a router that
/// has not been built, and the flow it names never runs.
class _Visits extends StatefulWidget {
  const _Visits({
    required this.router,
    required this.visits,
    required this.child,
  });

  final GoRouter router;
  final List<String> visits;
  final Widget child;

  @override
  State<_Visits> createState() => _VisitsState();
}

class _VisitsState extends State<_Visits> {
  @override
  void initState() {
    super.initState();
    _visit(0);
  }

  void _visit(int i) {
    if (i >= widget.visits.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // A route change takes a few frames to reach the screen; a `go` made
      // before that replaces the page before its flow scope has run. A
      // second is well past it, and about the pace of a reader's taps.
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      widget.router.go(widget.visits[i]);
      _visit(i + 1);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
