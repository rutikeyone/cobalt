// CobaltScope's debug* members are @experimental — outside semver, which newer
// analyzers flag on every use from another package. Reading the graph through
// them is what this file is for.
// ignore_for_file: experimental_member_use

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/src/build_time.dart';
import 'package:cobalt_inspector/src/cobalt_inspector_log.dart';
import 'package:cobalt_inspector/src/l10n/inspector_strings.dart';
import 'package:cobalt_inspector/src/registration_view.dart';
import 'package:cobalt_inspector/src/theme/cobalt_inspector_theme.dart';
import 'package:cobalt_inspector/src/widgets/chrome.dart';
import 'package:flutter/material.dart';

/// What is known about one registration, and the one thing you can do to it.
///
/// Everything shown is metadata — reading it does not touch the graph.
/// Building is offered separately and says what it costs, because resolving a
/// lazy singleton that nobody had asked for creates it for real: the object
/// starts existing, the scope takes ownership of it, and a creation event
/// appears in the log. An inspector that resolved rows to display them would
/// change the thing it is there to observe.
class RegistrationDetailSheet extends StatefulWidget {
  /// Describes [registration] as seen from [scope].
  const RegistrationDetailSheet({
    required this.scope,
    required this.registration,
    this.log,
    super.key,
  });

  /// The scope the registration was listed under.
  final CobaltScope scope;

  /// The registration to describe.
  final RegistrationView registration;

  /// Where the last build of [registration] is looked up, for its time.
  final CobaltInspectorLog? log;

  @override
  State<RegistrationDetailSheet> createState() =>
      _RegistrationDetailSheetState();
}

class _RegistrationDetailSheetState extends State<RegistrationDetailSheet> {
  String? _built;
  String? _failed;

  /// How long the most recent build of this registration took, from the
  /// log — its own key, built by the scope that owns it.
  Duration? _lastBuild() {
    final log = widget.log;
    if (log == null) return null;
    final registration = widget.registration;
    for (final entry in log.entries.reversed) {
      final record = entry.record;
      if (record.kind != CobaltEventKind.instanceCreated) continue;
      if (record.key != registration.key) continue;
      if (record.scope?.name != registration.owner.name) continue;
      return record.took;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final registration = widget.registration;
    final theme = CobaltInspectorTheme.of(context);
    final strings = inspectorStringsOf(context);

    return SafeArea(
      child: ListView(
        key: const Key('registration-detail'),
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${registration.key}',
                    style: (theme.monospace ?? const TextStyle(fontSize: 14))
                        .copyWith(color: theme.onSurface, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                LifetimeBadge(kind: registration.kind, theme: theme),
              ],
            ),
          ),
          Divider(height: 1, color: theme.outline),
          _Fact(label: strings.factOwnedBy, value: registration.owner.name),
          _Fact(
            label: strings.factReached,
            value: registration.isInherited
                ? strings.reachedInherited
                : strings.reachedHere,
          ),
          if (registration.isOverridden)
            _Fact(
              key: const Key('replaced-fact'),
              label: strings.factReplaced,
              value: strings.replacedByOverride,
            ),
          if (registration.decorators.isNotEmpty)
            _Fact(
              key: const Key('decorated-fact'),
              label: strings.factDecoratedBy,
              value: registration.decorators.join(' → '),
            ),
          if (_lastBuild() case final took?)
            _Fact(
              key: const Key('build-time-fact'),
              label: strings.factBuildTime,
              value: formatBuildTime(took),
            ),
          _Fact(
            label: strings.factTornDown,
            value: switch (registration.kind?.isRetained) {
              true => strings.tornDownYes,
              false => strings.tornDownNo,
              null => strings.tornDownUnknown,
            },
          ),
          if (_built case final value?)
            _Fact(
              key: const Key('built-value'),
              label: strings.factBuilt,
              value: value,
            ),
          if (_failed case final error?)
            _Fact(
              key: const Key('build-failed'),
              label: strings.factFailed,
              value: error,
            ),
          const Divider(height: 1),
          if (registration.isBuildable)
            ListTile(
              key: const Key('build-it'),
              title: Text(strings.buildItTitle),
              subtitle: Text(strings.buildItSubtitle),
              trailing: const Icon(Icons.play_arrow),
              onTap: _build,
            )
          else
            ListTile(
              key: const Key('not-buildable'),
              dense: true,
              title: Text(strings.notBuildable),
            ),
        ],
      ),
    );
  }

  Future<void> _build() async {
    try {
      final instance = await widget.scope.debugResolveAsync(
        widget.registration.key,
      );
      if (!mounted) return;
      setState(() => _built = '${instance.runtimeType}');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failed = '$error');
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) =>
      ListTile(dense: true, title: Text(label), subtitle: Text(value));
}
