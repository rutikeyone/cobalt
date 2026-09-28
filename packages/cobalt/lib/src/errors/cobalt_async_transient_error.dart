import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when an async transient registration is resolved synchronously.
///
/// Its factory returns a `Future` and builds a new instance on every call, so
/// unlike a lazy async singleton there is never a built instance for `get` to
/// hand back. `getAsync` awaits the build.
class CobaltAsyncTransientError extends CobaltError {
  /// Creates an error for the async transient [key].
  ///
  /// [resolving] is what was being built when the key was asked for, outermost
  /// first.
  CobaltAsyncTransientError(this.key, {this.resolving = const []})
    : super(_message(key, resolving));

  /// The key that was resolved synchronously.
  final CobaltKey key;

  /// The registrations under construction when this was asked for.
  final List<CobaltKey> resolving;

  static String _message(CobaltKey key, List<CobaltKey> resolving) {
    final what =
        '$key is built asynchronously on every resolution. Resolve it with '
        'getAsync<${key.type}>() — or getAllAsync for a list.';
    if (resolving.isEmpty) return what;
    final path = [...resolving, key].join(' -> ');
    return '$what Resolving: $path.';
  }
}
