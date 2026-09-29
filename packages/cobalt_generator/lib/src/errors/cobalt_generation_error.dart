/// A whole-package problem found while assembling the container, such as two
/// classes claiming to be the root scope.
final class CobaltGenerationError implements Exception {
  CobaltGenerationError(this.message);

  final String message;

  @override
  String toString() => 'CobaltGenerationError: $message';
}
