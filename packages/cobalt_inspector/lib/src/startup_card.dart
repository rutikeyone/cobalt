import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/src/build_time.dart';
import 'package:cobalt_inspector/src/l10n/cobalt_inspector_l10n.dart';
import 'package:cobalt_inspector/src/l10n/startup_strings.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_theme_data.dart';
import 'package:flutter/material.dart';

class StartupCard extends StatefulWidget {
  const StartupCard({
    required this.report,
    required this.theme,
    required this.strings,
    super.key,
  });

  final CobaltStartupReport report;
  final CobaltInspectorThemeData theme;
  final CobaltInspectorL10n strings;

  static bool hasContent(CobaltStartupReport report) =>
      report.bootstrap.isNotEmpty || report.builds.isNotEmpty;

  @override
  State<StartupCard> createState() => _StartupCardState();
}

class _StartupCardState extends State<StartupCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final report = widget.report;
    final mono = (t.monospace ?? const TextStyle(fontSize: 12)).copyWith(
      fontSize: 12,
      color: t.onSurface,
    );
    final waits = [
      for (final build in report.builds)
        if (build.took > build.self) build,
    ]..sort((a, b) => (b.took - b.self).compareTo(a.took - a.self));

    return Container(
      key: const Key('startup-card'),
      color: t.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('startup-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Icon(Icons.speed, size: 16, color: t.startup),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.strings.startupTook(formatBuildTime(report.total)),
                      key: const Key('startup-total'),
                      style: TextStyle(color: t.onSurface, fontSize: 13),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: t.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            if (report.bootstrap.isNotEmpty) ...[
              _Heading(text: widget.strings.startupSteps, theme: t),
              for (final step in report.bootstrap)
                _Line(
                  key: Key('startup-step-${step.step}'),
                  label: step.step,
                  value: formatBuildTime(step.took),
                  style: mono,
                  theme: t,
                ),
            ],
            if (waits.isNotEmpty) ...[
              _Heading(text: widget.strings.startupWaits, theme: t),
              for (final build in waits.take(5))
                _Line(
                  key: Key('startup-wait-${build.key}'),
                  label: '${build.key}',
                  value: widget.strings.waitedOf(
                    formatBuildTime(build.took - build.self),
                    formatBuildTime(build.took),
                  ),
                  style: mono,
                  theme: t,
                ),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.theme});

  final String text;
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
    child: Text(
      text,
      style: TextStyle(color: theme.muted, fontSize: 11, letterSpacing: 0.4),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.style,
    required this.theme,
    super.key,
  });

  final String label;
  final String value;
  final TextStyle style;
  final CobaltInspectorThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text(value, style: style.copyWith(color: theme.muted, fontSize: 11)),
      ],
    ),
  );
}
