import 'dart:async';

/// A single unit of phase-0 work, run before the container exists.
///
/// Steps run strictly in sequence, so a step may rely on everything declared
/// before it. Nothing can be injected into one — that is the point of the
/// phase, and why implementations are expected to be constructible with no
/// arguments.
///
/// Classes annotated `@CobaltBootstrap` are collected into `cobaltBootstrapSteps`
/// automatically; implementing this interface and passing the list by hand is
/// the Manual Mode equivalent.
abstract interface class CobaltBootstrapStep {
  /// Identifies the step in diagnostics and in `CobaltBootstrapError`.
  String get name;

  /// Performs the step. May be synchronous or asynchronous; either way the
  /// next step waits for it.
  FutureOr<void> run();
}
