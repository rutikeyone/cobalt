import 'package:cobalt/src/bootstrap/cobalt_scope_builder.dart';

/// What the generator writes for an `@CobaltChildScope` class: a builder
/// that knows which scope it builds and which it is declared to open under.
///
/// `CobaltScope.runBuilder` remembers [marker] on the scope it builds, and
/// when [parent] is set, checks that a scope above was built for it. When
/// none was, observers hear `onScopeParentMismatch` and a debug build says
/// so in the log: the scope was opened somewhere its declaration did not
/// allow, and the first thing it needs from the declared parent will fail
/// with `CobaltNotRegisteredError`.
abstract base class CobaltChildScopeBuilder implements CobaltScopeBuilder {
  /// Lets subclasses be `const`.
  const CobaltChildScopeBuilder();

  /// The `@CobaltChildScope` class this builder builds a scope for.
  Type get marker;

  /// The `@CobaltChildScope` class of the scope this one is declared to open
  /// under, or null when it opens under the root.
  Type? get parent => null;

  /// What this builder fills its scope from: the values of the marker in the
  /// order of its constructor, then the environment when it takes one.
  ///
  /// Two builders of one class with equal values are equal, so a
  /// `CobaltScopeWidget` rebuilt with `SessionScope(ada)` in place of an
  /// equal one keeps its scope, and opens a new one for `SessionScope(bob)`.
  /// The generator fills this in since 1.9.0. Null, the default, means the
  /// builder does not say: it is equal only to itself, and a
  /// `CobaltScopeWidget` reads it once.
  List<Object?>? get markerValues => null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final values = markerValues;
    if (values == null ||
        other is! CobaltChildScopeBuilder ||
        other.runtimeType != runtimeType) {
      return false;
    }
    final others = other.markerValues;
    if (others == null || others.length != values.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (values[i] != others[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final values = markerValues;
    if (values == null) return identityHashCode(this);
    return Object.hashAll([runtimeType, ...values]);
  }
}
