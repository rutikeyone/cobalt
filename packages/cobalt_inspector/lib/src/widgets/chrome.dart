import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/src/l10n/inspector_strings.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_family.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_theme_data.dart';
import 'package:flutter/material.dart';

/// Small pieces shared by the inspector's views.
///
/// Internal to the package and not exported: they exist so the three screens
/// agree on how a family, a lifetime and a timestamp look, not as an API.

/// A coloured mark for the family an event belongs to.
class FamilyMark extends StatelessWidget {
  /// Marks [family].
  const FamilyMark({
    required this.family,
    required this.theme,
    this.size = 18,
    super.key,
  });

  /// What the event is about.
  final CobaltInspectorFamily family;

  /// The palette in force.
  final CobaltInspectorThemeData theme;

  /// The icon's size.
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = theme.colorOfFamily(family);
    return Container(
      width: size + 12,
      height: size + 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: theme.tintAlpha),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(theme.iconOfFamily(family), size: size, color: color),
    );
  }
}

/// The lifetime of a registration, as a small tinted label.
class LifetimeBadge extends StatelessWidget {
  /// Labels [kind], or says it is gone when null.
  const LifetimeBadge({required this.kind, required this.theme, super.key});

  /// How long the registration lives.
  final CobaltRegistrationKind? kind;

  /// The palette in force.
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) {
    final kind = this.kind;
    final color = kind == null ? theme.muted : theme.colorOfLifetime(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: theme.tintAlpha),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: theme.borderAlpha)),
      ),
      child: Text(
        kind?.name ?? inspectorStringsOf(context).lifetimeGone,
        style: (theme.monospace ?? const TextStyle(fontSize: 11)).copyWith(
          color: color,
          fontSize: 11,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A small tag saying something about a registration beyond its lifetime —
/// that an override replaced it, or that a decorator wraps it.
class MarkerBadge extends StatelessWidget {
  /// Shows [label] in [color].
  const MarkerBadge({
    required this.label,
    required this.color,
    required this.theme,
    super.key,
  });

  /// What the tag says.
  final String label;

  /// Its colour, from the palette.
  final Color color;

  /// The palette in force.
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: theme.borderAlpha)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, height: 1.2),
    ),
  );
}

/// A wall-clock time, in the palette's monospace.
class Timestamp extends StatelessWidget {
  /// Shows [at], and the gap since [since] when there is one.
  const Timestamp({
    required this.at,
    required this.theme,
    this.since,
    super.key,
  });

  /// The moment to show.
  final DateTime at;

  /// The previous record's moment, for the gap.
  final DateTime? since;

  /// The palette in force.
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) {
    final since = this.since;
    final gap = since == null ? null : at.difference(since);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_clock(at), style: _style),
        if (gap != null && gap.inMilliseconds > 0)
          Text('+${gap.inMilliseconds}ms', style: _style),
      ],
    );
  }

  TextStyle get _style => (theme.monospace ?? const TextStyle(fontSize: 10))
      .copyWith(color: theme.muted, fontSize: 10, height: 1.3);

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}:'
      '${at.second.toString().padLeft(2, '0')}.'
      '${at.millisecond.toString().padLeft(3, '0')}';
}

/// The search field the log and the tree share.
class SearchField extends StatelessWidget {
  /// Filters as you type, reporting through [onChanged].
  const SearchField({
    required this.hint,
    required this.onChanged,
    required this.theme,
    super.key,
  });

  /// What is being searched, shown when the field is empty.
  final String hint;

  /// Called with every change.
  final ValueChanged<String> onChanged;

  /// The palette in force.
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: TextField(
      onChanged: onChanged,
      style: TextStyle(color: theme.onSurface, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(color: theme.muted, fontSize: 14),
        prefixIcon: Icon(Icons.search, size: 18, color: theme.muted),
        filled: true,
        fillColor: theme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.accent),
        ),
      ),
    ),
  );
}

/// What a view says when it has nothing to show.
class EmptyNote extends StatelessWidget {
  /// Says [text].
  const EmptyNote({required this.text, required this.theme, super.key});

  /// The line to show.
  final String text;

  /// The palette in force.
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(text, style: TextStyle(color: theme.muted, fontSize: 13)),
  );
}
