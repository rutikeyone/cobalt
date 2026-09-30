import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/src/build_time.dart';
import 'package:cobalt_inspector/src/cobalt_inspector_log.dart';
import 'package:cobalt_inspector/src/l10n/cobalt_inspector_l10n.dart';
import 'package:cobalt_inspector/src/l10n/inspector_strings.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_theme.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_theme_data.dart';
import 'package:cobalt_inspector/src/widgets/chrome.dart';
import 'package:flutter/material.dart';

/// How the built instances are arranged.
enum CreatedGrouping {
  /// Newest first, one flat list.
  flat,

  /// Gathered under the scope that built them.
  byScope,

  /// Gathered by how long they live.
  byLifetime,

  /// One flat list, the longest build first.
  slowest;

  /// What the switch shows for this option, in [strings]' language.
  String label(CobaltInspectorL10n strings) => switch (this) {
    CreatedGrouping.flat => strings.groupingFlat,
    CreatedGrouping.byScope => strings.groupingByScope,
    CreatedGrouping.byLifetime => strings.groupingByLifetime,
    CreatedGrouping.slowest => strings.groupingSlowest,
  };
}

/// What the graph actually built, newest first.
///
/// This is the one view that has to come from events. A scope's registrations
/// say what was *declared* — a lazy singleton nobody resolved is listed there
/// exactly like one that is built — so only a creation event proves an object
/// exists.
///
/// One thing it will never show: a value handed over already made — by
/// `registerSingleton` or `CobaltOverride.value`. Whoever built it did so
/// before the scope saw it, so the scope has nothing to report constructing.
/// It appears in the tree, with its lifetime, and never here. An eager
/// singleton is different: `registerEagerSingleton` builds it through its
/// factory on the spot, and that build is reported like any other.
class CreatedView extends StatefulWidget {
  /// Reads from [log].
  const CreatedView({required this.log, super.key});

  /// Where the creation events come from.
  final CobaltInspectorLog log;

  @override
  State<CreatedView> createState() => _CreatedViewState();
}

class _CreatedViewState extends State<CreatedView> {
  CreatedGrouping _grouping = CreatedGrouping.byScope;

  @override
  Widget build(BuildContext context) {
    final theme = CobaltInspectorTheme.of(context);
    final strings = inspectorStringsOf(context);

    return ListenableBuilder(
      listenable: widget.log,
      builder: (context, _) {
        final created = [
          for (final entry in widget.log.entries)
            if (entry.record.kind == CobaltEventKind.instanceCreated) entry,
        ].reversed.toList();

        return Container(
          color: theme.background,
          child: Column(
            children: [
              _GroupingSwitch(
                selected: _grouping,
                theme: theme,
                strings: strings,
                onChanged: (grouping) => setState(() => _grouping = grouping),
              ),
              Divider(height: 1, color: theme.outline),
              Expanded(
                child: created.isEmpty
                    ? EmptyNote(
                        key: const Key('nothing-built'),
                        text: strings.builtEmpty,
                        theme: theme,
                      )
                    : ListView(
                        key: const Key('created-list'),
                        children: _rows(created, theme),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _rows(List<CobaltLogEntry> created, CobaltInspectorThemeData t) {
    if (_grouping == CreatedGrouping.flat) {
      return [
        for (final entry in created) _CreatedTile(entry: entry, theme: t),
      ];
    }
    if (_grouping == CreatedGrouping.slowest) {
      final slowest = [...created]
        ..sort(
          (a, b) => (b.record.took ?? Duration.zero).compareTo(
            a.record.took ?? Duration.zero,
          ),
        );
      return [
        for (final entry in slowest) _CreatedTile(entry: entry, theme: t),
      ];
    }

    final groups = <String, List<CobaltLogEntry>>{};
    for (final entry in created) {
      final key = _grouping == CreatedGrouping.byScope
          ? entry.record.scope?.name ?? '?'
          : entry.record.registrationKind?.name ?? 'unknown';
      groups.putIfAbsent(key, () => []).add(entry);
    }

    return [
      for (final group in groups.entries) ...[
        _GroupHeader(label: group.key, count: group.value.length, theme: t),
        for (final entry in group.value) _CreatedTile(entry: entry, theme: t),
      ],
    ];
  }
}

class _GroupingSwitch extends StatelessWidget {
  const _GroupingSwitch({
    required this.selected,
    required this.theme,
    required this.strings,
    required this.onChanged,
  });

  final CreatedGrouping selected;
  final CobaltInspectorThemeData theme;
  final CobaltInspectorL10n strings;
  final ValueChanged<CreatedGrouping> onChanged;

  // Scrolls sideways, like the log's filters: four labels do not fit a phone
  // in every language — Russian ran well past the edge.
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Row(
      children: [
        for (final grouping in CreatedGrouping.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              key: Key('group-${grouping.name}'),
              onTap: () => onChanged(grouping),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(
                    alpha: selected == grouping
                        ? theme.selectedTintAlpha
                        : theme.idleTintAlpha,
                  ),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: selected == grouping ? theme.accent : theme.outline,
                  ),
                ),
                child: Text(
                  grouping.label(strings),
                  style: TextStyle(
                    color: selected == grouping ? theme.accent : theme.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    required this.theme,
  });

  final String label;
  final int count;
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('group-header-$label'),
    width: double.infinity,
    color: theme.surface,
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    child: Text(
      '$label · $count',
      style: TextStyle(color: theme.muted, fontSize: 11, letterSpacing: 0.4),
    ),
  );
}

class _CreatedTile extends StatelessWidget {
  const _CreatedTile({required this.entry, required this.theme});

  final CobaltLogEntry entry;
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) {
    final strings = inspectorStringsOf(context);
    final record = entry.record;
    return Padding(
      key: Key('created-${record.key}'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.key}',
                  style: (theme.monospace ?? const TextStyle(fontSize: 13))
                      .copyWith(color: theme.onSurface, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.builtWhere(
                    record.scope?.name ?? '?',
                    record.retained ?? false
                        ? strings.ownedByScope
                        : strings.ownedByCaller,
                  ),
                  style: TextStyle(color: theme.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (record.took case final took?) ...[
            const SizedBox(width: 8),
            Text(
              formatBuildTime(took),
              key: Key('took-${record.key}'),
              style: (theme.monospace ?? const TextStyle(fontSize: 11))
                  .copyWith(
                    fontSize: 11,
                    color: took >= theme.slowBuild
                        ? theme.warning
                        : theme.muted,
                    fontWeight: took >= theme.slowBuild
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
            ),
          ],
          const SizedBox(width: 8),
          LifetimeBadge(kind: record.registrationKind, theme: theme),
        ],
      ),
    );
  }
}
