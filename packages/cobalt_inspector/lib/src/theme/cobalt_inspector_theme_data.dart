import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_family.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The palette and type the inspector screens are drawn with.
///
/// The default is derived from the host application's own theme, so an
/// inspector dropped into an app already matches it without a line of
/// configuration. Pass one of these only where the derived answer is not the
/// one you want:
///
/// ```dart
/// CobaltInspectorTheme(
///   data: CobaltInspectorThemeData.of(Theme.of(context)).copyWith(
///     failure: brand.danger,
///     accent: brand.primary,
///   ),
///   child: child,
/// )
/// ```
///
/// Three things are drawn from a base colour rather than named directly — a
/// lifetime, a severity, a family's icon — and each has an override map beside
/// it. The maps are consulted per entry, so naming one lifetime leaves the
/// other four deriving as before:
///
/// ```dart
/// palette.copyWith(
///   lifetimeColors: {CobaltRegistrationKind.singleton: brand.gold},
/// )
/// ```
@immutable
class CobaltInspectorThemeData {
  /// Creates a palette outright. Prefer [CobaltInspectorThemeData.of].
  const CobaltInspectorThemeData({
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.muted,
    required this.outline,
    required this.accent,
    required this.scope,
    required this.startup,
    required this.instance,
    required this.failure,
    required this.warning,
    this.lifetimeColors,
    this.levelColors,
    this.familyIcons,
    this.monospace,
    this.dense = true,
    this.tintAlpha = 0.14,
    this.selectedTintAlpha = 0.22,
    this.idleTintAlpha = 0.06,
    this.borderAlpha = 0.4,
  });

  /// Derives a palette from the application's own theme.
  ///
  /// Everything comes from [ThemeData.colorScheme], so the inspector follows
  /// the host into light mode, dark mode and any brand seed. The family and
  /// severity colours are the one place this leans on more than the scheme: an
  /// event stream needs them far enough apart to scan, which `primary`,
  /// `secondary` and `tertiary` do not guarantee on a narrow seed, and a
  /// scheme has no slot for "warning" at all.
  factory CobaltInspectorThemeData.of(ThemeData theme) {
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return CobaltInspectorThemeData(
      background: scheme.surface,
      surface: scheme.surfaceContainerHighest,
      onSurface: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      outline: scheme.outlineVariant,
      accent: scheme.primary,
      scope: dark ? const Color(0xFF6FD3E8) : const Color(0xFF00728C),
      startup: dark ? const Color(0xFF74D99F) : const Color(0xFF117A48),
      instance: scheme.onSurfaceVariant,
      failure: scheme.error,
      warning: dark ? const Color(0xFFE8B45F) : const Color(0xFF8A5A00),
      monospace: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Consolas', 'Roboto Mono'],
      ),
    );
  }

  /// Behind everything.
  final Color background;

  /// Cards, sheets and grouped rows.
  final Color surface;

  /// Ordinary text.
  final Color onSurface;

  /// Secondary text: timestamps, counts, the line under a title.
  final Color muted;

  /// Hairlines and dividers.
  final Color outline;

  /// Selection, focus and the active filter.
  final Color accent;

  /// A scope appeared or went away.
  final Color scope;

  /// Startup: bootstrap steps and async initialization.
  final Color startup;

  /// An instance was built or released.
  final Color instance;

  /// Something failed.
  final Color failure;

  /// Something is worth attention without having failed.
  ///
  /// A dispose that threw is the ordinary case: the scope still reached
  /// `disposed`, and a resource still leaked.
  final Color warning;

  /// Colours for lifetimes that should not take the derived one.
  ///
  /// Read per entry, so a map naming one lifetime leaves the rest derived.
  /// Null — the default — derives every one. See [colorOfLifetime].
  final Map<CobaltRegistrationKind, Color>? lifetimeColors;

  /// Colours for severities that should not take the derived one.
  ///
  /// Read per entry, like [lifetimeColors]. See [colorOfLevel].
  final Map<CobaltLogLevel, Color>? levelColors;

  /// Icons for families that should not take the default one.
  ///
  /// Read per entry, like [lifetimeColors]. See [iconOfFamily].
  final Map<CobaltInspectorFamily, IconData>? familyIcons;

  /// For keys, timestamps and structured output. Falls back to the host's
  /// `bodySmall` where null.
  final TextStyle? monospace;

  /// Whether rows are packed tightly. A log is read in bulk, so they are.
  final bool dense;

  /// How strongly a coloured chip is filled: badges, family marks, tags.
  ///
  /// These four are opacities rather than colours because what a chip is
  /// filled with is its own colour, faded. On a light host the same value
  /// reads much weaker than on a dark one, which is why they are settings and
  /// not constants.
  final double tintAlpha;

  /// How strongly the chosen filter is filled.
  final double selectedTintAlpha;

  /// How strongly an unchosen filter is filled.
  final double idleTintAlpha;

  /// How strongly a chip's border is drawn.
  final double borderAlpha;

  /// The colour of one family.
  Color colorOfFamily(CobaltInspectorFamily family) => switch (family) {
    CobaltInspectorFamily.scope => scope,
    CobaltInspectorFamily.startup => startup,
    CobaltInspectorFamily.instance => instance,
    CobaltInspectorFamily.failure => failure,
  };

  /// The colour of one event, through its family.
  Color colorOfKind(CobaltEventKind kind) =>
      colorOfFamily(CobaltInspectorFamily.of(kind));

  /// The colour of one severity, from [levelColors] or derived.
  ///
  /// Only the two loud levels get one of their own; the quiet three read as
  /// ordinary text, which is what keeps a busy log scannable.
  Color colorOfLevel(CobaltLogLevel level) =>
      levelColors?[level] ??
      switch (level) {
        CobaltLogLevel.error => failure,
        CobaltLogLevel.warning => warning,
        CobaltLogLevel.info ||
        CobaltLogLevel.debug ||
        CobaltLogLevel.trace => muted,
      };

  /// The colour of one lifetime, from [lifetimeColors] or derived.
  ///
  /// Six lifetimes derive onto three colours, because the tree is read for
  /// what is retained rather than for how it was spelled. Name them when that
  /// is not the reading you want.
  Color colorOfLifetime(CobaltRegistrationKind kind) =>
      lifetimeColors?[kind] ??
      switch (kind) {
        CobaltRegistrationKind.singleton ||
        CobaltRegistrationKind.lazySingleton => scope,
        CobaltRegistrationKind.asyncSingleton ||
        CobaltRegistrationKind.lazyAsyncSingleton => startup,
        CobaltRegistrationKind.transient ||
        CobaltRegistrationKind.parameterized => instance,
      };

  /// The icon one family is marked with, from [familyIcons] or the default.
  IconData iconOfFamily(CobaltInspectorFamily family) =>
      familyIcons?[family] ??
      switch (family) {
        CobaltInspectorFamily.scope => Icons.account_tree_outlined,
        CobaltInspectorFamily.startup => Icons.play_circle_outline,
        CobaltInspectorFamily.instance => Icons.widgets_outlined,
        CobaltInspectorFamily.failure => Icons.error_outline,
      };

  @override
  bool operator ==(Object other) =>
      other is CobaltInspectorThemeData &&
      other.background == background &&
      other.surface == surface &&
      other.onSurface == onSurface &&
      other.muted == muted &&
      other.outline == outline &&
      other.accent == accent &&
      other.scope == scope &&
      other.startup == startup &&
      other.instance == instance &&
      other.failure == failure &&
      other.warning == warning &&
      mapEquals(other.lifetimeColors, lifetimeColors) &&
      mapEquals(other.levelColors, levelColors) &&
      mapEquals(other.familyIcons, familyIcons) &&
      other.monospace == monospace &&
      other.dense == dense &&
      other.tintAlpha == tintAlpha &&
      other.selectedTintAlpha == selectedTintAlpha &&
      other.idleTintAlpha == idleTintAlpha &&
      other.borderAlpha == borderAlpha;

  @override
  int get hashCode => Object.hash(
    background,
    surface,
    onSurface,
    muted,
    outline,
    accent,
    scope,
    startup,
    instance,
    failure,
    warning,
    _hashOf(lifetimeColors),
    _hashOf(levelColors),
    _hashOf(familyIcons),
    monospace,
    dense,
    tintAlpha,
    selectedTintAlpha,
    idleTintAlpha,
    borderAlpha,
  );

  /// A map's hash, independent of the order its entries were written in.
  static int _hashOf(Map<Object, Object?>? map) => map == null
      ? 0
      : Object.hashAllUnordered([
          for (final entry in map.entries) Object.hash(entry.key, entry.value),
        ]);

  /// A copy with some parts replaced.
  ///
  /// The three maps replace wholesale rather than merging: a caller holding a
  /// map is describing the whole exception, and a merge would make removing an
  /// entry impossible.
  CobaltInspectorThemeData copyWith({
    Color? background,
    Color? surface,
    Color? onSurface,
    Color? muted,
    Color? outline,
    Color? accent,
    Color? scope,
    Color? startup,
    Color? instance,
    Color? failure,
    Color? warning,
    Map<CobaltRegistrationKind, Color>? lifetimeColors,
    Map<CobaltLogLevel, Color>? levelColors,
    Map<CobaltInspectorFamily, IconData>? familyIcons,
    TextStyle? monospace,
    bool? dense,
    double? tintAlpha,
    double? selectedTintAlpha,
    double? idleTintAlpha,
    double? borderAlpha,
  }) => CobaltInspectorThemeData(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    onSurface: onSurface ?? this.onSurface,
    muted: muted ?? this.muted,
    outline: outline ?? this.outline,
    accent: accent ?? this.accent,
    scope: scope ?? this.scope,
    startup: startup ?? this.startup,
    instance: instance ?? this.instance,
    failure: failure ?? this.failure,
    warning: warning ?? this.warning,
    lifetimeColors: lifetimeColors ?? this.lifetimeColors,
    levelColors: levelColors ?? this.levelColors,
    familyIcons: familyIcons ?? this.familyIcons,
    monospace: monospace ?? this.monospace,
    dense: dense ?? this.dense,
    tintAlpha: tintAlpha ?? this.tintAlpha,
    selectedTintAlpha: selectedTintAlpha ?? this.selectedTintAlpha,
    idleTintAlpha: idleTintAlpha ?? this.idleTintAlpha,
    borderAlpha: borderAlpha ?? this.borderAlpha,
  );
}
