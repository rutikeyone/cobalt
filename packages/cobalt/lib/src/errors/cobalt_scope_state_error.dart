import 'package:cobalt/src/errors/cobalt_error.dart';

/// Thrown when a scope is used after it started disposing.
///
/// Registering into, resolving from, or pushing a child onto a disposed scope
/// all raise this rather than silently working against torn-down state.
final class CobaltScopeStateError extends CobaltError {
  /// Creates an error describing the illegal use.
  CobaltScopeStateError(super.message);
}
