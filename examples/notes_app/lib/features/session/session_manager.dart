import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:flutter/foundation.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/features/session/domain/session_user.dart';

class SessionManager extends ChangeNotifier {
  SessionManager(this._appScope);

  final CobaltScope _appScope;
  CobaltScope? _session;

  CobaltScope? get scope => _session;

  bool get isSignedIn => _session != null;

  SessionUser? get user => _session?.get<SessionUser>();

  Future<void> signIn(SessionUser user) async {
    await signOut();
    _session = await _appScope.open('session:${user.id}', SessionScope(user));
    notifyListeners();
  }

  Future<void> signOut() async {
    final scope = _session;
    if (scope == null) return;
    _session = null;
    await scope.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(signOut());
    super.dispose();
  }
}
