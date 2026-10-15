# cobalt_annotations example

Annotations only — they carry no runtime. The generator in `cobalt_generator`
reads them, and `cobalt_lint` checks them in the IDE.

```dart
import 'package:cobalt/cobalt.dart';

part 'notes.g.dart';

@cobaltInit
class Database implements AsyncInitializable {
  Database();

  @override
  Future<void> init() async { /* open the file */ }
}

@CobaltInject(exposeAs: NoteStore)
class NoteRepository implements NoteStore {
  NoteRepository(this.database);
  final Database database;
}

@CobaltInit(dependsOn: [Database])
class SearchIndex implements AsyncInitializable {
  SearchIndex(this.database);
  final Database database;

  @override
  Future<void> init() async { /* build the index */ }
}

@cobaltInject
class NoteEditor {
  NoteEditor(this.store, {@cobaltParam required this.id});

  final NoteStore store;
  final int id;
}

@cobaltTransient
class NotesController with _$NotesController {
  NotesController();

  @injected
  late final NoteStore _store;
}
```

A full application using every annotation lives in
[`examples/notes_app`](https://github.com/rutikeyone/cobalt/tree/main/examples/notes_app).

`SearchIndex` may state `dependsOn: [Database]` only because `Database` is `@CobaltInit` too.
`dependsOn` sequences phase 1, so it can wait for an async registration and nothing else; naming a
plain one fails the build.

`NoteEditor` takes an `@cobaltParam`, so it is registered as a parameterized factory and the
generator writes `typedef NoteEditorArgs = ({int id});` beside the container. Resolve it with `getWithParam<NoteEditor, NoteEditorArgs>((id: 7))` — the store still comes from the graph.
