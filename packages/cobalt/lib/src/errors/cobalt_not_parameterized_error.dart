import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when a parameterized resolve names a registration that takes no
/// parameter.
///
/// The mirror of [CobaltParamRequiredError]: one says you passed an argument
/// where none is wanted, the other that you passed none where one is.
final class CobaltNotParameterizedError extends CobaltError {
  /// Creates an error for [key], which is registered but not with a parameter.
  CobaltNotParameterizedError(this.key)
    : super(
        '$key is not registered as a parameterized factory; resolve it with '
        'get.',
      );

  /// The key that was resolved with a parameter.
  final CobaltKey key;
}
