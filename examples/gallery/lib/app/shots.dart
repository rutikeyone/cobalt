import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:flow_scopes/app/app_routes.dart';
import 'package:flutter/widgets.dart';
import 'package:gallery/catalog/catalog.dart';
import 'package:gallery/catalog/flow_scopes_host.dart';
import 'package:gallery/catalog/notes_graph.dart';
import 'package:gallery/features/hub/hub_screen.dart';
import 'package:notes_app/features/environments/ui/environments_screen.dart';

/// The screens the README shows, reachable by link.
///
/// `cobaltgallery:///shot/<name>` opens one exactly as a reader reaches it by
/// tapping — the inspector with a session open, the flow at its payment step,
/// the flow's log after two orders came and went — so `tool/screenshots.sh`
/// can shoot each without anybody at the simulator. The names are the files
/// under `assets/screenshots/`.
const shotPrefix = '/shot/';

final shots = <String, WidgetBuilder>{
  'hub': (_) => const HubScreen(),
  'tree': (_) => inspectorShot(CobaltInspectorTab.tree),
  'log': (_) => inspectorShot(CobaltInspectorTab.log),
  'flow': (_) => FlowScopesHost(initialLocation: AppRoutes.payment('1')),
  'flowlog': (_) => FlowScopesHost(
    visits: [AppRoutes.payment('1'), AppRoutes.payment('2'), AppRoutes.home],
  ),
  'env': (_) => notesGraph(const EnvironmentsScreen()),
};

/// The screen for a `/shot/<name>` route, or null for any other name.
WidgetBuilder? shotFor(String? route) {
  if (route == null || !route.startsWith(shotPrefix)) return null;
  return shots[route.substring(shotPrefix.length)];
}
