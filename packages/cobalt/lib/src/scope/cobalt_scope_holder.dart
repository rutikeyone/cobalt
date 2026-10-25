import 'dart:async';

import 'package:cobalt/src/bootstrap/cobalt_scope_builder.dart';
import 'package:cobalt/src/errors/cobalt_dispose_error.dart';
import 'package:cobalt/src/errors/cobalt_scope_state_error.dart';
import 'package:cobalt/src/observer/cobalt_observer.dart';
import 'package:cobalt/src/observer/cobalt_scope_ref.dart';
import 'package:cobalt/src/overrides/cobalt_override.dart';
import 'package:cobalt/src/scope/cobalt_scope.dart';

/// Holds at most one child scope of [parent] at a time: a signed-in session,
/// the open document, the selected account.
///
/// ```dart
/// final session = CobaltScopeHolder(app);
///
/// await session.open('session:${user.id}', SessionScope(user));
/// // later, on sign-out
/// await session.close();
/// ```
///
/// [open] closes the scope it holds before it opens the next one, and every
/// [open] and [close] runs after the ones called before it. So a sign-out
/// that arrives while a sign-in is still initializing its scope closes that
/// scope once it is open, instead of finding nothing to close and leaving it
/// behind.
///
/// [current] is null when nothing is open, and also once the scope it held
/// is no longer usable, for example because [parent] was disposed.
final class CobaltScopeHolder {
  /// Creates a holder of child scopes of [parent], holding nothing yet.
  CobaltScopeHolder(this.parent);

  /// The scope the held scopes are opened under.
  final CobaltScope parent;

  CobaltScope? _current;
  Future<void> _queue = Future.value();
  var _disposed = false;
  final _changes = StreamController<CobaltScope?>.broadcast();

  /// The scope held now, or null when there is none.
  CobaltScope? get current {
    final scope = _current;
    return scope != null && scope.isUsable ? scope : null;
  }

  /// The held scope each time it changes: the new one after [open], null
  /// when the one held is being closed.
  ///
  /// Null comes before the closed scope is torn down, so a listener stops
  /// reading from it before it becomes unusable.
  Stream<CobaltScope?> get changes => _changes.stream;

  /// Closes the scope held now, then opens [childName] under [parent] with
  /// [builder] and holds it.
  ///
  /// The arguments are those of [CobaltScope.open]. If [builder] or `init()`
  /// throws, nothing is held and the error reaches the caller; the scope
  /// held before is closed either way. A failure to close that scope reaches
  /// observers through `onScopeDisposed` and does not stop the open.
  ///
  /// Throws [CobaltScopeStateError] after [dispose].
  Future<CobaltScope> open(
    String childName,
    CobaltScopeBuilder builder, {
    List<CobaltObserver> observers = const [],
    List<CobaltOverride<Object>> overrides = const [],
    Duration? initTimeout,
  }) {
    if (_disposed) {
      return Future.error(
        CobaltScopeStateError(
          'This holder of scopes under "${parent.name}" was disposed, so '
          '"$childName" will not be opened.',
        ),
      );
    }
    return _enqueue(() async {
      await _closeHeld(rethrowFailure: false);
      final scope = await parent.open(
        childName,
        builder,
        observers: [...observers, _HeldScopeWatcher(this, parent.depth + 1)],
        overrides: overrides,
        initTimeout: initTimeout,
      );
      _current = scope;
      _emit(scope);
      return scope;
    });
  }

  /// Closes the scope held now, if there is one.
  ///
  /// A [CobaltDisposeError] from its teardown is rethrown once the holder
  /// already holds nothing.
  Future<void> close() => _enqueue(() => _closeHeld(rethrowFailure: true));

  /// Closes the scope held now and stops [changes]; [open] throws after it.
  Future<void> dispose() {
    if (_disposed) return _queue;
    _disposed = true;
    return _enqueue(() async {
      try {
        await _closeHeld(rethrowFailure: true);
      } finally {
        await _changes.close();
      }
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() step) {
    final result = _queue.then((_) => step());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _closeHeld({required bool rethrowFailure}) async {
    final scope = _current;
    if (scope == null) return;
    _current = null;
    _emit(null);
    try {
      await scope.dispose();
    } on CobaltDisposeError {
      if (rethrowFailure) rethrow;
    }
  }

  void _released() {
    final scope = _current;
    if (scope == null || scope.isUsable) return;
    _current = null;
    _emit(null);
  }

  void _emit(CobaltScope? scope) {
    if (!_changes.isClosed) _changes.add(scope);
  }
}

final class _HeldScopeWatcher extends CobaltObserver {
  _HeldScopeWatcher(this._holder, this._depth);

  final CobaltScopeHolder _holder;
  final int _depth;

  @override
  void onScopeDisposeStarted(CobaltScopeRef scope) {
    if (scope.depth == _depth) _holder._released();
  }
}
