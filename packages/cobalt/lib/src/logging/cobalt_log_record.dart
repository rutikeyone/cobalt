import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/logging/cobalt_log_level.dart';
import 'package:cobalt/src/observer/cobalt_event_kind.dart';
import 'package:cobalt/src/observer/cobalt_scope_ref.dart';
import 'package:cobalt/src/scope/cobalt_registration_kind.dart';
import 'package:meta/meta.dart';

/// One line an [CobaltLogSink] is asked to write.
///
/// [message] is already formatted, but [kind], [scope], [key] and [error] are
/// kept alongside it so a sink that can do better than a string — attaching the
/// scope as structured data, colouring by kind, keying on the event — still
/// can.
@immutable
final class CobaltLogRecord {
  /// Creates a record.
  const CobaltLogRecord({
    required this.kind,
    required this.level,
    required this.message,
    this.scope,
    this.key,
    this.registrationKind,
    this.retained,
    this.took,
    this.selfTook,
    this.error,
    this.stackTrace,
  });

  /// What happened, as a value.
  ///
  /// Required rather than optional: a record without one is exactly the gap
  /// this field exists to close, and an optional field would let it back in.
  final CobaltEventKind kind;

  /// How much this record matters.
  final CobaltLogLevel level;

  /// The formatted message.
  final String message;

  /// The scope the event happened in, when there is one.
  final CobaltScopeRef? scope;

  /// The registration the event was about, when there is one.
  final CobaltKey? key;

  /// How long the thing built lives, for a creation event.
  ///
  /// Null for every other kind. It is here rather than only in the message so
  /// a screen can group and filter on it instead of reading prose.
  final CobaltRegistrationKind? registrationKind;

  /// Whether the scope will dispose what it just built.
  ///
  /// Null for every other kind. Correlated with [registrationKind] today but
  /// not the same question: one is how long it lives, the other who closes it.
  final bool? retained;

  /// How long the build took, for a creation event — see
  /// `CobaltObserver.onInstanceBuilt` for what it includes.
  ///
  /// Null for every other kind.
  final Duration? took;

  /// How much of [took] the build spent on itself, without the builds it
  /// waited on, for a creation event — see `CobaltObserver.onInstanceSelfTime`.
  ///
  /// Null for every other kind.
  final Duration? selfTook;

  /// The failure, for warnings and errors.
  final Object? error;

  /// Where [error] came from.
  final StackTrace? stackTrace;

  /// Whether this record is about something going wrong.
  bool get isFailure => error != null;

  /// The record as data, for a destination that takes structured input.
  ///
  /// This is the whole of a GELF or JSON sink: hand the map over and let the
  /// destination decide what to index. Keys are stable — the message is free
  /// to be reworded, these are not.
  ///
  /// Null entries are dropped rather than sent as nulls, since most
  /// destinations treat a present-but-null field as a field.
  Map<String, Object?> toStructured() => {
    'event': kind.name,
    'level': level.name,
    'message': message,
    if (scope != null) ...{
      'scope': scope!.name,
      'scope_depth': scope!.depth,
      if (scope!.parentName != null) 'scope_parent': scope!.parentName,
    },
    if (key != null) 'key': key.toString(),
    if (registrationKind != null) 'lifetime': registrationKind!.name,
    if (retained != null) 'retained': retained,
    if (took != null) 'took_us': took!.inMicroseconds,
    if (selfTook != null) 'self_us': selfTook!.inMicroseconds,
    if (error != null) 'error': error.toString(),
    if (stackTrace != null) 'stack_trace': stackTrace.toString(),
  };

  @override
  String toString() => error == null ? message : '$message: $error';
}
