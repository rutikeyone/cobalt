import 'package:flutter/material.dart';
import 'package:gallery/catalog/example_host.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/app/app_startup.dart';
import 'package:notes_app/bootstrap/bootstrap_state.dart';

/// Mounts one `notes_app` screen with the notes graph beneath it.
///
/// Seven of the gallery's entries come from that one package, and each gets its
/// own graph rather than sharing one: open two of them and the scope trees are
/// unrelated, which is exactly what the entries are there to show.
Widget notesGraph(Widget screen) => _NotesExample(screen: screen);

class _NotesExample extends StatefulWidget {
  const _NotesExample({required this.screen});

  final Widget screen;

  @override
  State<_NotesExample> createState() => _NotesExampleState();
}

class _NotesExampleState extends State<_NotesExample> {
  @override
  void initState() {
    super.initState();
    // Phase 0 writes to statics because it has to — nothing can be injected
    // into a bootstrap step. Standing alone that was invisible; here a visit
    // builds a graph and leaving disposes it, so without this every visit
    // would read the last one's leftovers as its own.
    //
    // Cleared per visit rather than per start, deliberately: a restart should
    // still show "bind-platform released" followed by the next cycle, which is
    // the point of the restart button on that screen.
    resetBootstrapState();
  }

  @override
  Widget build(BuildContext context) => ExampleHost(
    root: const NotesScope(notesEnvironment),
    bootstrap: () => cobaltBootstrapSteps(notesEnvironment),
    rootName: cobaltRootScopeName,
    child: widget.screen,
  );
}
