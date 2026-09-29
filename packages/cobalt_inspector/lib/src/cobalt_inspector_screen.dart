import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/src/cobalt_inspector_log.dart';
import 'package:cobalt_inspector/src/created_view.dart';
import 'package:cobalt_inspector/src/event_log_view.dart';
import 'package:cobalt_inspector/src/scope_tree_view.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_theme.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_theme_data.dart';
import 'package:cobalt_inspector/src/l10n/inspector_strings.dart';
import 'package:flutter/material.dart';

/// The inspector: the live tree, what was built, and everything reported.
///
/// Push it from a debug menu, reading the scope at the push site:
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute<void>(
///     builder: (_) =>
///         CobaltInspectorScreen(log: log, scope: context.cobaltScope),
///   ),
/// );
/// ```
///
/// [scope] is passed rather than read from this screen's own context on
/// purpose. A pushed route is built by the navigator, which sits *above* the
/// `CobaltScopeProvider` in the tree — so looking the scope up from in here
/// finds nothing, however deep the button that opened it was. Any scope will
/// do; the screen climbs to its root.
///
/// [log] has to be the one passed to the graph when it was built. Observers
/// are fixed at construction, so an inspector cannot start listening to a
/// scope that is already running.
///
/// [theme] overrides whatever `CobaltInspectorTheme` is in force above this
/// screen. Leave it out and the palette is inherited, or derived from the
/// host's own `Theme` where nobody has set one — so an inspector dropped into
/// an app matches it without configuration.
class CobaltInspectorScreen extends StatelessWidget {
  /// Shows the graph [scope] belongs to, as recorded by [log].
  const CobaltInspectorScreen({
    required this.log,
    required this.scope,
    this.theme,
    super.key,
  });

  /// The palette to draw with, overriding the inherited one.
  final CobaltInspectorThemeData? theme;

  /// The recorder installed when the graph was built.
  final CobaltInspectorLog log;

  /// Any scope in the graph to show. The root is found from it.
  final CobaltScope scope;

  @override
  Widget build(BuildContext context) {
    final palette = theme ?? CobaltInspectorTheme.of(context);
    final strings = inspectorStringsOf(context);
    final root = scope.root;

    return CobaltInspectorTheme(
      data: palette,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: palette.background,
          appBar: AppBar(
            backgroundColor: palette.background,
            foregroundColor: palette.onSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              strings.inspectorTitle,
              style: TextStyle(color: palette.onSurface, fontSize: 16),
            ),
            actions: [
              ListenableBuilder(
                listenable: log,
                builder: (context, _) => IconButton(
                  key: const Key('pause-log'),
                  tooltip: log.isPaused
                      ? strings.resumeTooltip
                      : strings.pauseTooltip,
                  icon: Icon(
                    log.isPaused ? Icons.play_arrow : Icons.pause,
                    color: log.isPaused ? palette.accent : palette.muted,
                  ),
                  onPressed: () => log.isPaused ? log.resume() : log.pause(),
                ),
              ),
              IconButton(
                key: const Key('clear-log'),
                tooltip: strings.clearTooltip,
                icon: Icon(Icons.delete_outline, color: palette.muted),
                onPressed: log.clear,
              ),
            ],
            bottom: TabBar(
              labelColor: palette.accent,
              unselectedLabelColor: palette.muted,
              indicatorColor: palette.accent,
              dividerColor: palette.outline,
              tabs: [
                Tab(key: const Key('tab-tree'), text: strings.tabTree),
                _CountedTab(
                  key: const Key('tab-created'),
                  label: strings.tabBuilt,
                  count: () => log.created.length,
                  log: log,
                ),
                _CountedTab(
                  key: const Key('tab-log'),
                  label: strings.tabLog,
                  count: () => log.records.length,
                  log: log,
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _Reactive(
                log: log,
                child: ScopeTreeView(root: root, log: log),
              ),
              CreatedView(log: log),
              EventLogView(log: log),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tab that says how much is behind it.
class _CountedTab extends StatelessWidget implements PreferredSizeWidget {
  const _CountedTab({
    required this.label,
    required this.count,
    required this.log,
    super.key,
  });

  final String label;
  final int Function() count;
  final CobaltInspectorLog log;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: log,
    builder: (context, _) {
      final n = count();
      return Tab(text: n == 0 ? label : '$label · $n');
    },
  );
}

/// Rebuilds [child] whenever the graph reports anything.
///
/// A scope is not a [Listenable] and pushing one notifies nothing, so a view
/// over the live tree would otherwise keep showing the tree as it was when the
/// screen opened. The event stream is the only signal there is that something
/// moved; it does not say *what* moved, which is enough to re-walk the tree.
class _Reactive extends StatelessWidget {
  const _Reactive({required this.log, required this.child});

  final CobaltInspectorLog log;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: log, builder: (context, _) => child);
}
