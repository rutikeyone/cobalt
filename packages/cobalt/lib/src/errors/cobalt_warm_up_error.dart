import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown by `CobaltScope.warmUp` when some of the builds it started failed.
///
/// Every build runs to the end before this is thrown, so one failure does not
/// hide another and the registrations that did build stay built. A failed
/// build is not cached: the next `getAsync` of that key tries again.
class CobaltWarmUpError extends CobaltError {
  /// Creates an error listing [failures] from [scopeName], with the stack
  /// trace of each in [stackTraces].
  CobaltWarmUpError(this.scopeName, this.failures, this.stackTraces)
    : super(_describe(scopeName, failures));

  /// The scope `warmUp` was called on.
  final String scopeName;

  /// What each failed build threw, in the order the keys were given.
  final Map<CobaltKey, Object> failures;

  /// Where each entry of [failures] was thrown.
  final Map<CobaltKey, StackTrace> stackTraces;

  static String _describe(String scope, Map<CobaltKey, Object> failures) {
    final lines = [
      for (final MapEntry(:key, :value) in failures.entries) '  $key: $value',
    ].join('\n');
    return 'Warming up scope "$scope" failed to build ${failures.length} '
        'registration(s).\n$lines';
  }
}
