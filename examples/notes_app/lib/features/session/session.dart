import 'package:cobalt/cobalt.dart';
import 'package:notes_app/features/session/domain/session_user.dart';

@CobaltChildScope()
class Session {
  const Session(this.user);

  final SessionUser user;
}
