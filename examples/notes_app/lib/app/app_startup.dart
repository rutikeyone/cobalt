import 'package:cobalt/cobalt.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/features/session/session_manager.dart';

const _requestedEnvironment = String.fromEnvironment('NOTES_ENV');

/// The environment this build was compiled for.
///
/// `flutter run --dart-define=NOTES_ENV=prod` picks another one. It has to be
/// known before the graph is built, which is why it is a compile-time constant
/// and not something a bootstrap step loads.
///
/// The fallback is [CobaltEnvironment.dev] itself rather than the string `dev`:
/// a literal here would be a second place to keep the name right, and getting
/// it wrong would silently select an environment nothing claims.
const notesEnvironment = _requestedEnvironment == ''
    ? CobaltEnvironment.dev
    : CobaltEnvironment(_requestedEnvironment);

/// The whole root scope: what the generator found, plus the two things it
/// cannot know about.
///
/// Composing a builder rather than registering after `startCobalt` returns is
/// what keeps these two inside phase 1 — registered before async initializers
/// run, not bolted on after the graph is already up.
class NotesScope implements CobaltScopeBuilder {
  const NotesScope(this.environment);

  final CobaltEnvironment environment;

  @override
  void build(CobaltScope scope) {
    CobaltRoot(environment: environment).build(scope);
    scope
      ..registerSingleton<CobaltEnvironment>(environment)
      ..registerSingleton<SessionManager>(SessionManager(scope));
  }
}
