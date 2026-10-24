import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:flutter/foundation.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/features/session/domain/session_user.dart';

class SessionManager extends ChangeNotifier {
  SessionManager(CobaltScope appScope)
    : _session = CobaltScopeHolder(appScope) {
    _changes = _session.changes.listen((_) => notifyListeners());
  }

  final CobaltScopeHolder _session;
  late final StreamSubscription<CobaltScope?> _changes;

  CobaltScope? get scope => _session.current;

  bool get isSignedIn => scope != null;

  SessionUser? get user => scope?.get<SessionUser>();

  Future<void> signIn(SessionUser user) async {
    await _session.open('session:${user.id}', SessionScope(user));
  }

  Future<void> signOut() async {
    await _session.close();
  }

  @override
  void dispose() {
    unawaited(_changes.cancel());
    unawaited(_session.dispose());
    super.dispose();
  }
}
