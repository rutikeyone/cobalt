// CobaltScope's debug* members are @experimental — outside semver, which newer
// analyzers flag on every use from another package. Reading the graph through
// them is what this file is for.
// ignore_for_file: experimental_member_use

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';
import 'package:notes_app/l10n/notes_app_l10n.dart';
import 'package:notes_app/features/session/session_manager.dart';

class ScopeTreeScreen extends StatefulWidget {
  const ScopeTreeScreen({super.key});

  @override
  State<ScopeTreeScreen> createState() => _ScopeTreeScreenState();
}

class _ScopeTreeScreenState extends State<ScopeTreeScreen> {
  SessionManager? _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.cobalt<SessionManager>();
    if (identical(session, _session)) return;
    _session?.removeListener(_onChanged);
    _session = session;
    session.addListener(_onChanged);
  }

  @override
  void dispose() {
    _session?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final root = context.cobaltScope;

    return Scaffold(
      appBar: AppBar(title: Text(NotesL10n.of(context).scopeTree)),
      body: ListView(
        key: const Key('scope-tree'),
        children: [
          for (final line in root.debugDescribeTree().split('\n'))
            ListTile(dense: true, title: Text(line)),
        ],
      ),
    );
  }
}
