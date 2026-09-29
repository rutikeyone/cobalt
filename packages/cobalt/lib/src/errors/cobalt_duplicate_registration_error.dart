import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when the same key is registered twice in one scope.
///
/// Overriding a dependency is done by registering it again in a *child* scope,
/// which shadows the ancestor without mutating it. That is also the intended
/// way to swap a dependency for a test double.
final class CobaltDuplicateRegistrationError extends CobaltError {
  /// Creates an error for the duplicated [key] in [scopeName].
  CobaltDuplicateRegistrationError(this.key, this.scopeName)
    : super('$key is already registered in scope "$scopeName".');

  /// The key that was registered twice.
  final CobaltKey key;

  /// The scope that already held the key.
  final String scopeName;
}
