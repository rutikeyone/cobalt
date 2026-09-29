import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when an async singleton is requested before `init()` has built it.
///
/// Cobalt reports this instead of returning a half-built object, so an ordering
/// mistake surfaces at the point it happens.
final class CobaltNotReadyError extends CobaltError {
  /// Creates an error for the not-yet-initialized [key].
  ///
  /// [resolving] is what was being built when the key was asked for, outermost
  /// first — the same trail [CobaltNotRegisteredError] carries, because the
  /// question it answers is the same one: which class do I have to change.
  CobaltNotReadyError(this.key, {this.resolving = const []})
    : super(_message(key, resolving));

  /// The key that is not ready yet.
  final CobaltKey key;

  /// The registrations under construction when this was asked for.
  final List<CobaltKey> resolving;

  static String _message(CobaltKey key, List<CobaltKey> resolving) {
    final what =
        '$key is an async registration and was requested before init().';
    if (resolving.isEmpty) return what;
    final path = [...resolving, key].join(' -> ');
    return '$what Resolving: $path.';
  }
}
