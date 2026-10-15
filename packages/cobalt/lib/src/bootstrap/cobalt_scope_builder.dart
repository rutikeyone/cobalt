import 'package:cobalt/src/scope/cobalt_scope.dart';

/// Declares what goes into a scope.
///
/// Implementations are registration-only: they add to the scope and return,
/// leaving construction to the scope itself. Passing a builder object rather
/// than a closure is what lets the generated `CobaltRoot` be `const`, and
/// makes a scope's contents an inspectable value instead of captured state.
abstract interface class CobaltScopeBuilder {
  /// Adds this builder's registrations to [scope].
  void build(CobaltScope scope);
}
