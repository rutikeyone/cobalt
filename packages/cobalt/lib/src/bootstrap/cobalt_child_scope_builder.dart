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
}
