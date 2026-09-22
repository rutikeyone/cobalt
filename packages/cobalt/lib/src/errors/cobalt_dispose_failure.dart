import 'dart:async';

import 'package:cobalt/src/errors/cobalt_dispose_stage.dart';
import 'package:meta/meta.dart';

/// One step of teardown that did not complete.
@immutable
final class CobaltDisposeFailure {
  /// Records that [label] failed with [error] during [stage].
  const CobaltDisposeFailure(
    this.label,
    this.error,
    this.stackTrace, {
    this.stage = CobaltDisposeStage.releasing,
  });

  /// What was being torn down, such as `EventLog.dispose`, `init`, or
  /// `session/CacheStore.dispose` for a step inside a child scope.
  final String label;

  /// Why it did not complete. A [TimeoutException] means the step ran past the
  /// deadline and was abandoned rather than having failed on its own.
  final Object error;

  /// Where [error] came from.
  final StackTrace stackTrace;

  /// Which part of teardown this came from.
  final CobaltDisposeStage stage;

  /// Whether this step ran out of time instead of throwing.
  bool get isTimeout => error is TimeoutException;

  /// Whether this is an initialization failure rather than a teardown failure.
  ///
  /// An initialization that *threw* never makes `dispose` throw by itself —
  /// the error belongs to whoever called `init()` and was already delivered
  /// there, so it appears only as context saying the scope was never fully
  /// built. An initialization that ran past the deadline is different: waiting
  /// for it is teardown's own work, so [isTimeout] entries here are reported
  /// like any other overrun.
  bool get isInitFailure => stage == CobaltDisposeStage.awaitingInit;

  /// Whether this is a build failure rather than a teardown failure.
  ///
  /// [isInitFailure], plus a lazy async build that threw while teardown was
  /// waiting for it. The same reasoning holds for both: the error already
  /// reached whoever was waiting for the build.
  bool get isBuildFailure =>
      isInitFailure || stage == CobaltDisposeStage.awaitingLazyBuild;

  @override
  String toString() => switch (stage) {
    CobaltDisposeStage.awaitingInit when !isTimeout =>
      '$label — initialization failed before teardown started: $error',
    CobaltDisposeStage.awaitingLazyBuild when !isTimeout =>
      '$label — the lazy build failed before teardown started: $error',
    _ => '$label — $error',
  };
}
