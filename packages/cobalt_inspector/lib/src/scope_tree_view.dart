import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/src/registration_detail_sheet.dart';
import 'package:cobalt_inspector/src/registration_view.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_theme.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_theme_data.dart';
import 'package:cobalt_inspector/src/widgets/chrome.dart';
import 'package:cobalt_inspector/src/l10n/inspector_strings.dart';
import 'package:flutter/material.dart';

/// The live scope tree, with what each scope registers.
///
/// Walks the scope objects rather than the event stream. An event carries an
/// `CobaltScopeRef`, which is a name, a depth and a parent name — two
/// same-named siblings are indistinguishable there, and so are a scope that
/// was disposed and one pushed later under the same name. As a label that is
/// fine; as the identity of a node it is not.
///
/// Expansion is held here rather than by `ExpansionTile`, because the tree is
/// rebuilt from live scopes on every event and "collapse all" has to be able
/// to reach every node at once.
class ScopeTreeView extends StatefulWidget {
  /// Shows the tree rooted at [root].
  const ScopeTreeView({required this.root, super.key});

  /// The scope to render, along with everything under it.
  final CobaltScope root;

  @override
  State<ScopeTreeView> createState() => _ScopeTreeViewState();
}

class _ScopeTreeViewState extends State<ScopeTreeView> {
  final _collapsed = <String>{};
  String _query = '';

  String _id(CobaltScope scope) => '${scope.name}-${scope.depth}';

  @override
  Widget build(BuildContext context) {
    final theme = CobaltInspectorTheme.of(context);
    final strings = inspectorStringsOf(context);
    final nodes = _walk(widget.root).toList();

    return Container(
      color: theme.background,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SearchField(
                  key: const Key('tree-search'),
                  hint: strings.treeSearchHint,
                  theme: theme,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              IconButton(
                key: const Key('collapse-all'),
                tooltip: _collapsed.isEmpty
                    ? strings.collapseAll
                    : strings.expandAll,
                icon: Icon(
                  _collapsed.isEmpty ? Icons.unfold_less : Icons.unfold_more,
                  color: theme.muted,
                ),
                onPressed: () => setState(() {
                  if (_collapsed.isEmpty) {
                    _collapsed.addAll(nodes.map(_id));
                  } else {
                    _collapsed.clear();
                  }
                }),
              ),
              const SizedBox(width: 4),
            ],
          ),
          Divider(height: 1, color: theme.outline),
          Expanded(
            child: ListView(
              key: const Key('scope-tree'),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final scope in nodes)
                  _ScopeNode(
                    scope: scope,
                    theme: theme,
                    query: _query,
                    isCollapsed: _collapsed.contains(_id(scope)),
                    onToggle: () => setState(() {
                      final id = _id(scope);
                      if (!_collapsed.remove(id)) _collapsed.add(id);
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Iterable<CobaltScope> _walk(CobaltScope scope) sync* {
    yield scope;
    for (final child in scope.children) {
      yield* _walk(child);
    }
  }
}

class _ScopeNode extends StatelessWidget {
  const _ScopeNode({
    required this.scope,
    required this.theme,
    required this.query,
    required this.isCollapsed,
    required this.onToggle,
  });

  final CobaltScope scope;
  final CobaltInspectorThemeData theme;
  final String query;
  final bool isCollapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final strings = inspectorStringsOf(context);
    final registrations = RegistrationView.of(scope);
    final own = registrations.where((r) => !r.isInherited).length;
    final shown = query.isEmpty
        ? registrations
        : [
            for (final registration in registrations)
              if ('${registration.key}'.toLowerCase().contains(query))
                registration,
          ];

    return Padding(
      padding: EdgeInsets.only(left: scope.depth * 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: Key('scope-${scope.name}-${scope.depth}'),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Icon(
                    isCollapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 18,
                    color: theme.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    scope.name,
                    style: TextStyle(
                      color: theme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    text: scope.state.name,
                    color: scope.state == CobaltScopeState.active
                        ? theme.startup
                        : theme.muted,
                    theme: theme,
                  ),
                  const Spacer(),
                  Text(
                    strings.nodeCounts(own, scope.children.length),
                    style: TextStyle(color: theme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            for (final registration in shown)
              _RegistrationTile(
                scope: scope,
                registration: registration,
                theme: theme,
              ),
          if (!isCollapsed && shown.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(38, 0, 12, 10),
              child: Text(
                query.isEmpty
                    ? strings.treeNothingRegistered
                    : strings.treeNoMatch,
                style: TextStyle(color: theme.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.theme});

  final String text;
  final Color color;
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: theme.tintAlpha),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 10)),
  );
}

class _RegistrationTile extends StatelessWidget {
  const _RegistrationTile({
    required this.scope,
    required this.registration,
    required this.theme,
  });

  final CobaltScope scope;
  final RegistrationView registration;
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('registration-${registration.key}'),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.background,
      builder: (_) => CobaltInspectorTheme(
        data: theme,
        child: RegistrationDetailSheet(
          scope: scope,
          registration: registration,
        ),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(38, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${registration.key}',
              style: (theme.monospace ?? const TextStyle(fontSize: 12))
                  .copyWith(
                    color: registration.isInherited
                        ? theme.muted
                        : theme.onSurface,
                    fontSize: 12,
                  ),
            ),
          ),
          if (registration.isOverridden) ...[
            const SizedBox(width: 6),
            MarkerBadge(
              key: Key('overridden-${registration.key}'),
              label: inspectorStringsOf(context).badgeOverridden,
              color: theme.warning,
              theme: theme,
            ),
          ],
          if (registration.decorators.isNotEmpty) ...[
            const SizedBox(width: 6),
            MarkerBadge(
              key: Key('decorated-${registration.key}'),
              label: inspectorStringsOf(context).badgeDecorated,
              color: theme.accent,
              theme: theme,
            ),
          ],
          const SizedBox(width: 8),
          LifetimeBadge(kind: registration.kind, theme: theme),
          if (registration.isInherited) ...[
            const SizedBox(width: 6),
            Icon(Icons.subdirectory_arrow_right, size: 14, color: theme.muted),
          ],
        ],
      ),
    ),
  );
}
