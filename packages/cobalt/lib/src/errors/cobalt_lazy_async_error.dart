import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when a lazy async registration is read synchronously before it is
/// built.
///
/// A lazy async singleton is built by the first `getAsync`, not by `init()`,
/// so a synchronous `get` has nothing to hand back until then. Once it is
/// built, `get` returns it like any other singleton.
class CobaltLazyAsyncError extends CobaltError {
  /// Creates an error for the unbuilt [key].
  ///
  /// [resolving] is what was being built when the key was asked for, outermost
  /// first.
  CobaltLazyAsyncError(this.key, {this.resolving = const []})
    : super(_message(key, resolving));

  /// The key that has not been built yet.
  final CobaltKey key;

  /// The registrations under construction when this was asked for.
  final List<CobaltKey> resolving;

  static String _message(CobaltKey key, List<CobaltKey> resolving) {
    final what =
        '$key is a lazy async registration and has not been built yet. '
        'Resolve it with getAsync<${key.type}>() — or getAllAsync for a list — '
        'and the first call builds it.';
    if (resolving.isEmpty) return what;
    final path = [...resolving, key].join(' -> ');
    return '$what Resolving: $path.';
  }
}
