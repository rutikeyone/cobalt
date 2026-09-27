import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when an async parameterized registration is resolved synchronously.
///
/// Its factory returns a `Future`, so `getWithParam` has nothing to hand back
/// yet. `getAsyncWithParam` awaits the build.
class CobaltAsyncParamError extends CobaltError {
  /// Creates an error for the async parameterized [key].
  CobaltAsyncParamError(this.key)
    : super(
        '$key is built asynchronously from its parameter; resolve it with '
        'getAsyncWithParam.',
      );

  /// The key that was resolved synchronously.
  final CobaltKey key;
}
