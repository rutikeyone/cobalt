import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';

/// What one registration looks like to the inspector.
///
/// Built from a live scope rather than from events: the scope knows what it
/// registers and, through `registrationOf`, how long each one lives. Reading it
/// costs nothing and builds nothing.
@immutable
class RegistrationView {
  /// Describes [key] as seen from a scope.
  const RegistrationView({
    required this.key,
    required this.kind,
    required this.owner,
    required this.isInherited,
    this.isOverridden = false,
    this.decorators = const [],
    this.implementation,
  });

  /// Everything [scope] can resolve, its own registrations first.
  ///
  /// Inherited entries carry the scope that owns them, which is the fact that
  /// decides what an override actually affects: a factory runs on the scope
  /// that owns *its* registration, not the one you asked from.
  static List<RegistrationView> of(CobaltScope scope) {
    final own = scope.keys;
    return [
      for (final entry in scope.visibleKeys.entries)
        _describe(entry.key, entry.value, scope.registrationOf(entry.key), own),
    ]..sort((a, b) {
      if (a.isInherited != b.isInherited) return a.isInherited ? 1 : -1;
      return a.key.toString().compareTo(b.key.toString());
    });
  }

  static RegistrationView _describe(
    CobaltKey key,
    CobaltScope owner,
    CobaltRegistrationInfo? info,
    Set<CobaltKey> own,
  ) => RegistrationView(
    key: key,
    kind: info?.kind,
    owner: owner,
    isInherited: !own.contains(key),
    isOverridden: owner.overriddenKeys.contains(key),
    decorators: info?.decorators ?? const [],
    implementation: switch (info?.implementation) {
      final built? when built != '${key.type}' => built,
      _ => null,
    },
  );

  /// The type, and the name when it has one.
  final CobaltKey key;

  /// How long it lives, or null when the scope no longer holds it.
  final CobaltRegistrationKind? kind;

  /// The scope that will build it.
  final CobaltScope owner;

  /// Whether it comes from an ancestor rather than from the scope asked.
  final bool isInherited;

  /// Whether an override stands in for it on [owner].
  final bool isOverridden;

  /// What wraps it, innermost first; empty when nothing does.
  final List<String> decorators;

  /// The class it builds, when its factory says and that is not the key's
  /// own type — `LiveApiClient` behind `ApiClient`; null otherwise.
  final String? implementation;

  /// Whether it can be built without a value from the caller.
  bool get isBuildable => kind?.takesParam == false;
}
