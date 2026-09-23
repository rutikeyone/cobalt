import 'package:flutter/foundation.dart';

/// What the graph did, recorded as a fact rather than as a sentence.
///
/// The log is shown on screen, and everything that writes to it — a draft, a
/// tab marker — is resolved from a scope: no `BuildContext`, and so no way to
/// know the reader's language. So the domain records what happened and the
/// screen says it. That split is what makes a layer below the widgets
/// localizable at all.
enum FlowEventKind {
  /// A scope appeared.
  scopeBuilt,

  /// A scope went away.
  scopeDisposed,

  /// A flow built its draft.
  draftCreated,

  /// A flow's draft went with it.
  draftDisposed,

  /// The cart flow built its draft.
  cartCreated,

  /// The cart flow's draft went with it.
  cartDisposed,
}

@immutable
class FlowEvent {
  /// Records that [kind] happened to [subject].
  const FlowEvent(this.kind, this.subject);

  /// What happened.
  final FlowEventKind kind;

  /// Which scope or order it happened to — a name from the app, not prose, so
  /// it reads the same in every language.
  final String subject;

  @override
  bool operator ==(Object other) =>
      other is FlowEvent && other.kind == kind && other.subject == subject;

  @override
  int get hashCode => Object.hash(kind, subject);

  @override
  String toString() => '${kind.name}:$subject';
}
