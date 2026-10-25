import 'dart:async';

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/foundation.dart';

/// Collects what the graph reports, for the inspector screens to read.
///
/// Pass it where the graph is built — observers are fixed when a scope is
/// constructed and handed down to its children, so this cannot be attached
/// later, when a screen opens:
///
/// ```dart
/// final log = CobaltInspectorLog();
/// final scope = await CobaltApplication.start(
///   root: const AppScope(),
///   observers: [log],
/// );
/// ```
///
/// It is also the only change signal the tree screen has. A scope is not a
/// [Listenable] and pushing a child notifies nothing, so a view over the live
/// tree repaints when this says something moved.
final class CobaltInspectorLog extends CobaltRecordingObserver
    with ChangeNotifier {
  /// Keeps the last [capacity] records.
  ///
  /// A graph of any size builds a lot of instances, and a screen only ever
  /// shows the recent past. The default is generous enough to cover a whole
  /// startup.
  CobaltInspectorLog({this.capacity = 500})
    : assert(capacity > 0, 'a log of no records watches nothing');

  /// How many records are kept before the oldest is dropped.
  final int capacity;

  final _entries = <CobaltLogEntry>[];
  var _disposed = false;
  var _isPaused = false;
  var _missedWhilePaused = false;

  /// Whether new records are being withheld from listeners.
  bool get isPaused => _isPaused;

  /// Everything seen, oldest first, each with the moment it arrived.
  List<CobaltLogEntry> get entries => List.unmodifiable(_entries);

  /// Everything seen, oldest first.
  List<CobaltLogRecord> get records => [
    for (final entry in _entries) entry.record,
  ];

  /// Only what was built, oldest first.
  ///
  /// Comes from events rather than from a scope's registrations, because those
  /// answer a different question: `keys` is what was *declared*, and a lazy
  /// singleton nobody resolved looks there exactly like one that is built.
  List<CobaltLogRecord> get created => [
    for (final entry in _entries)
      if (entry.record.kind == CobaltEventKind.instanceCreated) entry.record,
  ];

  /// The records of one kind, oldest first.
  List<CobaltLogRecord> ofKind(CobaltEventKind kind) => [
    for (final entry in _entries)
      if (entry.record.kind == kind) entry.record,
  ];

  /// Stops waking listeners. Records keep arriving and are kept.
  ///
  /// For reading a stream that will not hold still: the graph does not stop
  /// because a screen is open, and a list that reorders under a finger is not
  /// readable. Nothing is dropped — [resume] shows what came in.
  void pause() {
    if (_isPaused) return;
    _isPaused = true;
    notifyListeners();
  }

  /// Resumes waking listeners, and shows whatever arrived meanwhile.
  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    final missed = _missedWhilePaused;
    _missedWhilePaused = false;
    if (missed) {
      _notify();
    } else {
      notifyListeners();
    }
  }

  /// Forgets everything seen so far.
  void clear() {
    _entries.clear();
    _notify();
  }

  final _startup = CobaltStartupObserver();

  /// What the cold start of the graph spent its time on: the bootstrap
  /// steps, the singletons the start built, and how long each waited for its
  /// dependencies.
  ///
  /// Read from the same events as the records, so it needs the log installed
  /// when the graph starts; empty when it was installed later.
  CobaltStartupReport get startup => _startup.report;

  @override
  void onBootstrapStepStarted(String step) {
    _startup.onBootstrapStepStarted(step);
    super.onBootstrapStepStarted(step);
  }

  @override
  void onBootstrapStepCompleted(String step, Duration took) {
    _startup.onBootstrapStepCompleted(step, took);
    super.onBootstrapStepCompleted(step, took);
  }

  @override
  void onInstanceSelfTime(CobaltScopeRef scope, CobaltKey key, Duration self) {
    _startup.onInstanceSelfTime(scope, key, self);
    super.onInstanceSelfTime(scope, key, self);
  }

  @override
  void onInstanceBuilt(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
    required Duration took,
  }) {
    _startup.onInstanceBuilt(
      scope,
      key,
      kind: kind,
      retained: retained,
      took: took,
    );
    super.onInstanceBuilt(
      scope,
      key,
      kind: kind,
      retained: retained,
      took: took,
    );
  }

  @override
  void onRecord(CobaltLogRecord record) {
    if (_entries.length == capacity) _entries.removeAt(0);
    // Stamped on arrival rather than carried by the record. Observers are
    // called synchronously inside the work they describe, so this is the
    // moment the event happened — and it keeps the runtime's record free of a
    // field only a screen wants.
    _entries.add(CobaltLogEntry(record, DateTime.now()));
    if (_isPaused) {
      _missedWhilePaused = true;
      return;
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Notifies after the current turn, never during it.
  ///
  /// Observer callbacks are synchronous and arrive in the middle of the work
  /// they describe — including a teardown that runs while the tree is
  /// building, where a synchronous notification throws
  /// `setState() called during build`.
  ///
  /// Deferring buys that at the cost of a notification outliving its listener:
  /// tearing a scope down emits events, and whoever owns this log usually
  /// disposes it in the same turn. The guard is for exactly that gap.
  void _notify() => scheduleMicrotask(() {
    if (_disposed) return;
    notifyListeners();
  });
}

/// One record and the moment it arrived.
@immutable
class CobaltLogEntry {
  /// Pairs [record] with [at].
  const CobaltLogEntry(this.record, this.at);

  /// What was reported.
  final CobaltLogRecord record;

  /// When the observer was called, which is when the event happened.
  final DateTime at;
}
