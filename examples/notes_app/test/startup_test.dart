import 'package:cobalt/cobalt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/bootstrap/boot_log.dart';
import 'package:notes_app/core/event_log.dart';
import 'package:notes_app/features/diagnostics/data/telemetry.dart';
import 'package:notes_app/features/notes/data/note_database.dart';
import 'package:notes_app/features/notes/data/search_index.dart';

import 'support.dart';

void main() {
  setUp(BootLog.reset);

  group('generated bootstrap', () {
    test('runs every annotated step, ordered by its declared order', () async {
      await startNotesGraph();

      expect(BootLog.steps, [
        'bind-platform',
        'load-remote-config',
        'warm-fonts',
      ]);
    });

    test('finishes before any dependency is constructed', () async {
      final app = await startNotesGraph();

      final log = app.get<EventLog>().entries;
      expect(BootLog.steps, hasLength(3));
      expect(log, isNot(contains('bind-platform')));
      expect(log, contains('database opened'));
    });

    test('independent initializers share a level, so neither waits', () async {
      final app = await startNotesGraph();

      final log = app.get<EventLog>().entries;
      expect(
        log,
        containsAll(['database opened', 'telemetry started']),
        reason: 'both run, and which lands first is not a contract',
      );
      expect(
        log.indexOf('search index built'),
        greaterThan(log.indexOf('database opened')),
        reason: 'dependsOn is the only ordering the graph promises',
      );
    });

    test('the root scope takes its name from @CobaltScopeRoot', () async {
      final app = await startNotesGraph();

      expect($cobaltRootScopeName, 'app');
      expect(app.name, 'app');
    });

    test('a failing step aborts the start and names itself', () async {
      await expectLater(
        CobaltApplication.start(
          root: const $CobaltRootScope(environment: CobaltEnvironment.test),
          bootstrap: [_ExplodingStep()],
        ),
        throwsA(
          isA<CobaltBootstrapError>().having(
            (e) => e.step,
            'step',
            'exploding',
          ),
        ),
      );
    });
  });

  group('the root scope owns the bootstrap steps', () {
    test('a step holding a resource is released with the scope', () async {
      final app = await startNotesGraph();
      final binding = BootLog.steps;

      expect(binding, contains('bind-platform'));
      expect(binding, isNot(contains('bind-platform released')));

      await app.dispose();

      expect(BootLog.steps, contains('bind-platform released'));
    });

    test('every start gets its own step instances', () async {
      final first = await startNotesGraph();
      await first.dispose();

      BootLog.reset();
      await startNotesGraph();

      expect(
        BootLog.steps,
        ['bind-platform', 'load-remote-config', 'warm-fonts'],
        reason: 'a stored list would have reused the first run instances',
      );
    });
  });

  group('generated async init graph', () {
    test('every @CobaltInit service is ready when start returns', () async {
      final app = await startNotesGraph();

      expect(app.get<NoteDatabase>().isOpen, isTrue);
      expect(app.get<SearchIndex>().isBuilt, isTrue);
      expect(app.get<Telemetry>().isStarted, isTrue);
    });

    test('dependsOn is honoured: the index waits for the database', () async {
      final app = await startNotesGraph();

      final entries = app.get<EventLog>().entries;
      expect(
        entries.indexOf('database opened'),
        lessThan(entries.indexOf('search index built')),
      );
    });

    test(
      'independent initializers share a level and run in parallel',
      () async {
        final watch = Stopwatch()..start();
        final app = await startNotesGraph();
        watch.stop();

        expect(app.get<Telemetry>().isStarted, isTrue);
        expect(
          watch.elapsedMilliseconds,
          lessThan(60),
          reason: 'database and telemetry run together, then the index',
        );
      },
    );

    test('async services are unavailable before init', () {
      final scope = CobaltScope.root();
      const $CobaltRootScope(environment: CobaltEnvironment.test).build(scope);

      expect(
        () => scope.get<NoteDatabase>(),
        throwsA(isA<CobaltNotReadyError>()),
      );
    });
  });
}

class _ExplodingStep implements CobaltBootstrapStep {
  @override
  String get name => 'exploding';

  @override
  void run() => throw StateError('no native library');
}
