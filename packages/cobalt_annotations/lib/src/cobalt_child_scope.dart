import 'package:cobalt_annotations/src/cobalt_provided.dart';
import 'package:meta/meta_meta.dart';

/// Declares a scope shorter than the app, whose builder the generator writes.
///
/// The annotated class is a marker, never instantiated by the generated code.
/// Its name, with `Scope` appended, names the builder: `Session` gives
/// `SessionScope`. Its constructor says what the scope is opened with, and
/// each parameter is registered in it as a value:
///
/// ```dart
/// @CobaltChildScope()
/// class Session {
///   const Session(this.user);
///   final SessionUser user;
/// }
///
/// @CobaltInject(scope: Session)
/// class SessionActivityLog {
///   SessionActivityLog(this.user, this.events);
///   final SessionUser user;
///   final EventLog events;
/// }
///
/// final session = await app.open('session', SessionScope(user));
/// ```
///
/// `SessionScope` registers `user` and every class annotated with
/// `scope: Session`. The build checks that each of them gets what it injects
/// from this scope or the ones above it, and that nothing above injects what
/// only this scope registers.
///
/// Every constructor parameter has to be an initializing formal
/// (`this.user`), and required: the generated builder repeats the
/// constructor, and a default value would not travel with it. `@Named` on the
/// parameter registers the value under that name.
@Target({TargetKind.classType})
class CobaltChildScope {
  /// Creates an annotation declaring a child scope.
  const CobaltChildScope({this.parent, this.provides = const []});

  /// The child scope this one opens under, or null for the root.
  ///
  /// It decides what the build lets registrations here inject. At run time
  /// the scope resolves through whatever it was opened under; opened where
  /// no scope above was built for [parent], it is reported to observers as
  /// `onScopeParentMismatch`, and fails with `CobaltNotRegisteredError` on
  /// the first thing it cannot find.
  final Type? parent;

  /// Registrations made in this scope by hand, which registrations here may
  /// depend on. As for `CobaltScopeRoot.provides`, an element is a `Type` or
  /// a [CobaltProvided].
  final List<Object> provides;
}
