import 'package:meta/meta_meta.dart';

/// Marks a constructor parameter as a value the call site supplies.
///
/// Everything else in a constructor comes from the graph. This is for what the
/// container cannot know — a record id, a route argument, a flag chosen on the
/// screen that opened this one.
///
/// The class is then registered as a parameterized factory, and resolved with
/// `getWithParam` rather than `get`. The generator writes the argument type
/// beside the container as a named record built from the marked parameters:
///
/// ```dart
/// @cobaltInject
/// class NoteEditor {
///   NoteEditor(this._notes, {@cobaltParam required this.id, @cobaltParam this.draft = false});
///
///   final NoteRepository _notes;
///   final int id;
///   final bool draft;
/// }
///
/// // typedef $NoteEditorArgs = ({int id, bool draft});
/// context.cobaltWithParam<NoteEditor, $NoteEditorArgs>((id: 7, draft: true));
/// ```
///
/// A record even for a single value, and a named one: adding a second argument
/// then changes what you pass rather than the name of the type, and the call
/// site keeps reading like the constructor it stands for.
///
/// On an `@CobaltInit` class it becomes an async parameterized factory: each
/// `getAsyncWithParam` builds one, awaiting `init()`. Such a class is not
/// built in phase 1, so it takes neither `lazy: true` nor `dependsOn`. Not
/// compatible with a singleton lifetime either, since a scope never retains
/// what it builds from a call-site value.
@Target({TargetKind.parameter})
class CobaltParam {
  /// Marks the parameter.
  const CobaltParam();
}

/// The one you write: `@cobaltParam`.
const cobaltParam = CobaltParam();
