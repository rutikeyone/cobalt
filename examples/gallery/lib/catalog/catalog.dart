import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:codegen_basics/cobalt.g.dart' as codegen;
import 'package:codegen_basics/counter_screen.dart';
import 'package:flutter/material.dart';
import 'package:gallery/catalog/decorators_graph.dart';
import 'package:gallery/catalog/decorators_screen.dart';
import 'package:gallery/catalog/example_entry.dart';
import 'package:gallery/catalog/example_host.dart';
import 'package:gallery/catalog/example_section.dart';
import 'package:gallery/catalog/flow_scopes_host.dart';
import 'package:gallery/catalog/glyphs.dart';
import 'package:gallery/catalog/inspector_graph.dart';
import 'package:gallery/catalog/lazy_async_graph.dart';
import 'package:gallery/catalog/lazy_async_screen.dart';
import 'package:gallery/design/gallery_theme.dart';
import 'package:gallery/l10n/gallery_l10n.dart';
import 'package:gallery/catalog/notes_graph.dart';
import 'package:graph_events/app/app_scope.dart';
import 'package:graph_events/app/audit_log.dart';
import 'package:graph_events/app/observers.dart';
import 'package:graph_events/app/report_log.dart';
import 'package:graph_events/features/home/ui/home_screen.dart' as events;
import 'package:notes_app/features/diagnostics/ui/scope_tree_screen.dart';
import 'package:notes_app/features/environments/ui/environments_screen.dart';
import 'package:notes_app/features/formatting/ui/formatters_screen.dart';
import 'package:notes_app/features/home/ui/home_screen.dart' as notes;
import 'package:notes_app/features/note_detail/ui/note_detail_screen.dart';
import 'package:notes_app/features/notes/ui/notes_screen.dart';
import 'package:notes_app/features/session/ui/session_screen.dart';
import 'package:talker/talker.dart';

/// Every capability the framework has an example for.
///
/// Ordered by section, and within a section by what to read first. The list is
/// deliberately not grouped by which package a screen came from — that is an
/// implementation detail of the repository, not something a reader is looking
/// for.
List<ExampleEntry> buildCatalog(GalleryL10n l10n) => [
  // ── Startup ───────────────────────────────────────────────────────────
  ExampleEntry(
    id: 'startup',
    title: l10n.startupTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.startup,
    teaches: l10n.startupTeaches,
    glyph: Glyphs.notes,
    points: [
      l10n.startupPoint1,
      l10n.startupPoint2,
      l10n.startupPoint3,
      l10n.startupPoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript: 'examples/notes_app/lib/features/home/ui/home_screen.dart',
    open: (_) => notesGraph(const notes.HomeScreen()),
  ),
  ExampleEntry(
    id: 'environments',
    title: l10n.environmentsTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.startup,
    teaches: l10n.environmentsTeaches,
    glyph: Glyphs.codegen,
    points: [
      l10n.environmentsPoint1,
      l10n.environmentsPoint2,
      l10n.environmentsPoint3,
      l10n.environmentsPoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript:
        'examples/notes_app/lib/features/environments/ui/environments_screen.dart',
    open: (_) => notesGraph(const EnvironmentsScreen()),
  ),
  ExampleEntry(
    id: 'lazy-async',
    title: l10n.lazyAsyncTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.startup,
    teaches: l10n.lazyAsyncTeaches,
    glyph: Glyphs.flow,
    points: [
      l10n.lazyAsyncPoint1,
      l10n.lazyAsyncPoint2,
      l10n.lazyAsyncPoint3,
      l10n.lazyAsyncPoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript: 'examples/gallery/lib/catalog/lazy_async_graph.dart',
    open: (_) => const ExampleHost(
      root: LazyAsyncScope(),
      rootName: 'lazy-async',
      child: LazyAsyncScreen(),
    ),
  ),

  // ── Injection ─────────────────────────────────────────────────────────
  ExampleEntry(
    id: 'property',
    title: l10n.propertyTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.injection,
    teaches: l10n.propertyTeaches,
    glyph: Glyphs.flow,
    points: [
      l10n.propertyPoint1,
      l10n.propertyPoint2,
      l10n.propertyPoint3,
      l10n.propertyPoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript: 'examples/notes_app/lib/features/notes/ui/notes_screen.dart',
    open: (_) => notesGraph(const NotesScreen()),
  ),
  ExampleEntry(
    id: 'named',
    title: l10n.namedTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.injection,
    teaches: l10n.namedTeaches,
    glyph: Glyphs.testing,
    points: [l10n.namedPoint1, l10n.namedPoint2, l10n.namedPoint3],
    transcriptLabel: l10n.whereItLives,
    transcript:
        'examples/notes_app/lib/features/formatting/ui/formatters_screen.dart',
    open: (_) => notesGraph(const FormattersScreen()),
  ),
  ExampleEntry(
    id: 'decorators',
    title: l10n.decoratorsTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.injection,
    teaches: l10n.decoratorsTeaches,
    glyph: Glyphs.flow,
    points: [
      l10n.decoratorsPoint1,
      l10n.decoratorsPoint2,
      l10n.decoratorsPoint3,
      l10n.decoratorsPoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript: 'examples/gallery/lib/catalog/decorators_graph.dart',
    open: (_) => const ExampleHost(
      root: DecoratorsScope(),
      rootName: 'decorators',
      child: DecoratorsScreen(),
    ),
  ),

  // ── Scopes & lifetime ─────────────────────────────────────────────────
  ExampleEntry(
    id: 'widget-scope',
    title: l10n.widgetScopeTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.scopes,
    teaches: l10n.widgetScopeTeaches,
    glyph: Glyphs.manual,
    points: [
      l10n.widgetScopePoint1,
      l10n.widgetScopePoint2,
      l10n.widgetScopePoint3,
      l10n.widgetScopePoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript:
        'examples/notes_app/lib/features/note_detail/ui/note_detail_screen.dart',
    open: (_) => notesGraph(const NoteDetailScreen()),
  ),
  ExampleEntry(
    id: 'session',
    title: l10n.sessionTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.scopes,
    teaches: l10n.sessionTeaches,
    glyph: Glyphs.events,
    points: [l10n.sessionPoint1, l10n.sessionPoint2, l10n.sessionPoint3],
    transcriptLabel: l10n.whereItLives,
    transcript:
        'examples/notes_app/lib/features/session/ui/session_screen.dart',
    open: (_) => notesGraph(const SessionScreen()),
  ),
  ExampleEntry(
    id: 'scope-tree',
    title: l10n.scopeTreeTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.scopes,
    teaches: l10n.scopeTreeTeaches,
    glyph: Glyphs.notes,
    points: [l10n.scopeTreePoint1, l10n.scopeTreePoint2, l10n.scopeTreePoint3],
    transcriptLabel: l10n.whereItLives,
    transcript:
        'examples/notes_app/lib/features/diagnostics/ui/scope_tree_screen.dart',
    open: (_) => notesGraph(const ScopeTreeScreen()),
  ),
  ExampleEntry(
    id: 'flow',
    title: l10n.flowTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.scopes,
    teaches: l10n.flowTeaches,
    glyph: Glyphs.flow,
    points: [
      l10n.flowPoint1,
      l10n.flowPoint2,
      l10n.flowPoint3,
      l10n.flowPoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript: 'examples/flow_scopes/lib/app/app_router.dart',
    open: (_) => const FlowScopesHost(),
  ),
  ExampleEntry(
    id: 'teardown',
    title: l10n.teardownTitle,
    kind: ExampleKind.terminal,
    section: ExampleSection.scopes,
    teaches: l10n.teardownTeaches,
    glyph: Glyphs.teardown,
    points: [
      l10n.teardownPoint1,
      l10n.teardownPoint2,
      l10n.teardownPoint3,
      l10n.teardownPoint4,
    ],
    transcriptLabel: l10n.consoleOutput,
    transcript: 'cd examples/teardown\ndart run bin/main.dart',
  ),

  // ── Code generation ───────────────────────────────────────────────────
  ExampleEntry(
    id: 'codegen',
    title: l10n.codegenTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.codegen,
    teaches: l10n.codegenTeaches,
    glyph: Glyphs.codegen,
    points: [
      l10n.codegenPoint1,
      l10n.codegenPoint2,
      l10n.codegenPoint3,
      l10n.codegenPoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript: 'examples/codegen_basics/lib/counter_screen.dart',
    open: (_) => const ExampleHost(
      root: codegen.$CobaltRootScope(),
      rootName: codegen.$cobaltRootScopeName,
      child: CounterScreen(),
    ),
  ),
  ExampleEntry(
    id: 'manual',
    title: l10n.manualTitle,
    kind: ExampleKind.terminal,
    section: ExampleSection.codegen,
    teaches: l10n.manualTeaches,
    glyph: Glyphs.manual,
    points: [
      l10n.manualPoint1,
      l10n.manualPoint2,
      l10n.manualPoint3,
      l10n.manualPoint4,
    ],
    transcriptLabel: l10n.consoleOutput,
    transcript: 'cd examples/manual_mode\ndart run bin/main.dart',
  ),

  // ── Observability ─────────────────────────────────────────────────────
  ExampleEntry(
    id: 'events',
    title: l10n.eventsTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.observability,
    teaches: l10n.eventsTeaches,
    glyph: Glyphs.events,
    points: [
      l10n.eventsPoint1,
      l10n.eventsPoint2,
      l10n.eventsPoint3,
      l10n.eventsPoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript: 'examples/graph_events/lib/app/graph_events_app.dart',
    open: (_) => const _GraphEventsHost(),
  ),
  ExampleEntry(
    id: 'inspector',
    title: l10n.inspectorTitle,
    kind: ExampleKind.screen,
    section: ExampleSection.observability,
    teaches: l10n.inspectorTeaches,
    glyph: Glyphs.notes,
    points: [
      l10n.inspectorPoint1,
      l10n.inspectorPoint2,
      l10n.inspectorPoint3,
      l10n.inspectorPoint4,
    ],
    transcriptLabel: l10n.whereItLives,
    transcript:
        'packages/cobalt_inspector/lib/src/cobalt_inspector_screen.dart',
    open: (_) => const _InspectorHost(),
  ),

  // ── Testing ───────────────────────────────────────────────────────────
  ExampleEntry(
    id: 'testing',
    title: l10n.testingTitle,
    kind: ExampleKind.terminal,
    section: ExampleSection.testing,
    teaches: l10n.testingTeaches,
    glyph: Glyphs.testing,
    points: [
      l10n.testingPoint1,
      l10n.testingPoint2,
      l10n.testingPoint3,
      l10n.testingPoint4,
    ],
    transcriptLabel: l10n.testOutput,
    transcript: 'cd examples/testing_patterns\nflutter test',
  ),
];

/// The catalog grouped for display, in section order.
List<SectionedEntries<ExampleEntry>> buildSections(GalleryL10n l10n) {
  final all = buildCatalog(l10n);
  return [
    for (final section in ExampleSection.values)
      if (all.where((e) => e.section == section).toList() case final entries
          when entries.isNotEmpty)
        SectionedEntries(section: section, entries: entries),
  ];
}

/// The inspector entry, with a graph of its own beneath it.
///
/// The log has to be installed when the graph is built, because observers are
/// fixed at construction — so the host owns one per visit, and a second visit
/// starts with an empty trail rather than the last one's.
class _InspectorHost extends StatefulWidget {
  const _InspectorHost();

  @override
  State<_InspectorHost> createState() => _InspectorHostState();
}

class _InspectorHostState extends State<_InspectorHost> {
  final _log = CobaltInspectorLog();

  @override
  void dispose() {
    _log.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExampleHost(
    root: const InspectorScope(),
    bootstrap: () => [InspectorWarmUp()],
    rootName: 'inspector',
    observers: [_log],
    child: _InspectorDemo(log: _log),
  );
}

/// Something for the graph to do, then the inspector to look at it with.
class _InspectorDemo extends StatefulWidget {
  const _InspectorDemo({required this.log});

  final CobaltInspectorLog log;

  @override
  State<_InspectorDemo> createState() => _InspectorDemoState();
}

class _InspectorDemoState extends State<_InspectorDemo> {
  CobaltScope? _session;

  Future<void> _openSession() async {
    if (_session != null) return;
    final scope = context.cobaltScope.push('session');
    const InspectorSessionScope().build(scope);
    await scope.init();
    if (!mounted) return;
    setState(() => _session = scope);
  }

  Future<void> _closeSession() async {
    final scope = _session;
    if (scope == null) return;
    await scope.dispose();
    if (!mounted) return;
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = GalleryL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.demoTitle),
        actions: [
          IconButton(
            key: const Key('open-inspector'),
            tooltip: l10n.demoInspect,
            icon: const Icon(Icons.account_tree_outlined),
            // The scope is read here, below the provider — a pushed route is
            // built by the navigator, which sits above it.
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CobaltInspectorScreen(
                  log: widget.log,
                  scope: context.cobaltScope,
                  // The gallery's own palette, so the inspector reads as part
                  // of this app rather than as a panel bolted onto it.
                  theme: galleryInspectorTheme(context),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            key: const Key('open-session'),
            enabled: _session == null,
            title: Text(l10n.demoOpenSession),
            subtitle: Text(l10n.demoOpenSessionHint),
            trailing: const Icon(Icons.login),
            onTap: _openSession,
          ),
          ListTile(
            key: const Key('close-session'),
            enabled: _session != null,
            title: Text(l10n.demoCloseSession),
            subtitle: Text(
              _session == null ? l10n.demoNothingOpen : l10n.demoTearsItDown,
            ),
            trailing: const Icon(Icons.logout),
            onTap: _closeSession,
          ),
          const Divider(),
          ListTile(
            dense: true,
            title: Text(l10n.demoThenOpen),
            subtitle: Text(l10n.demoThenOpenHint),
          ),
        ],
      ),
    );
  }
}

/// The observability entry, with everything it watches with built per open.
///
/// Fresh each visit rather than shared: the observers hold this talker and
/// this report log, and a second visit should start with an empty trail.
class _GraphEventsHost extends StatefulWidget {
  const _GraphEventsHost();

  @override
  State<_GraphEventsHost> createState() => _GraphEventsHostState();
}

class _GraphEventsHostState extends State<_GraphEventsHost> {
  final _talker = Talker();
  final _audit = AuditLog();
  final _reports = ReportLog();

  @override
  void dispose() {
    _reports.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExampleHost(
    root: const AppScope(),
    bootstrap: () => [WarmUp()],
    rootName: 'app',
    observers: graphEventsObservers(
      talker: _talker,
      audit: _audit,
      reports: _reports,
    ),
    child: events.HomeScreen(talker: _talker, reports: _reports),
  );
}
