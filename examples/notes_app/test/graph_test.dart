import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/bootstrap/boot_log.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/core/app_config.dart';
import 'package:notes_app/core/clock.dart';
import 'package:notes_app/core/event_log.dart';
import 'package:notes_app/features/note_detail/ui/note_draft.dart';
import 'package:notes_app/features/notes/data/note_database.dart';
import 'package:notes_app/features/notes/data/note_repository.dart';
import 'package:notes_app/features/notes/domain/note_store.dart';
import 'package:notes_app/features/notes/ui/notes_controller.dart';

import 'support.dart';

void main() {
  late CobaltScope app;

  setUp(() async {
    BootLog.reset();
    app = await startNotesGraph();
  });

  tearDown(() async => app.dispose());

  group('generated registrations', () {
    test('exposeAs registers the interface and hides the implementation', () {
      expect(app.isRegistered<NoteStore>(), isTrue);
      expect(app.isRegistered<NoteRepository>(), isFalse);
      expect(app.get<NoteStore>(), isA<NoteRepository>());
    });

    test('lifetimes follow the annotations', () {
      expect(app.get<Clock>(), same(app.get<Clock>()));
      expect(
        app.get<NotesController>(),
        isNot(same(app.get<NotesController>())),
      );
    });

    test('an eager singleton is built during registration', () {
      expect(app.get<AppConfig>().apiBaseUrl, 'https://notes.example/v1');
    });
  });

  group('property injection', () {
    test(
      'the controller receives its dependencies with no constructor args',
      () {
        final controller = app.get<NotesController>();

        expect(controller, isA<CobaltInjectable>());
        expect(controller.notes, isEmpty);

        controller.add('groceries');

        expect(controller.notes.single.title, 'groceries');
        expect(app.get<EventLog>().entries, contains('created note-1'));
      },
    );

    test('injected singletons are shared between controller instances', () {
      app.get<NotesController>().add('first');

      expect(app.get<NotesController>().notes, hasLength(1));
    });

    test('search goes through the initialized index', () {
      final controller = app.get<NotesController>()
        ..add('shopping list')
        ..add('reading list');

      expect(controller.search('shopping'), hasLength(1));
      expect(controller.search('list'), hasLength(2));
    });
  });

  group('scopes', () {
    test(
      'a child scope adds its own registrations over the app graph',
      () async {
        final detail = await app.openForTest(const NoteDetailScope());

        expect(detail.get<NoteDraft>(), isNotNull);
        expect(app.isRegistered<NoteDraft>(), isFalse);
        expect(detail.get<NoteStore>(), same(app.get<NoteStore>()));
      },
    );

    test('closing a child disposes only what the child owns', () async {
      final detail = app.push('note-detail')..registerScope();
      final draft = detail.get<NoteDraft>();

      await detail.dispose();

      expect(draft.isDiscarded, isTrue);
      expect(app.get<NoteDatabase>().isOpen, isTrue);
      expect(app.children, isEmpty);
    });

    test(
      'disposing the app tears down children first, then its own graph',
      () async {
        app.push('note-detail')
          ..registerScope()
          ..get<NoteDraft>();
        final log = app.get<EventLog>();

        await app.dispose();

        expect(
          log.entries,
          containsAllInOrder([
            'draft discarded',
            'database closed',
            'event-log closed',
          ]),
        );
      },
    );
  });
}

extension on CobaltScope {
  void registerScope() => runBuilder(const NoteDetailScope());
}
