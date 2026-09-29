import 'package:cobalt/src/errors/cobalt_dispose_failure.dart';
import 'package:cobalt/src/errors/cobalt_dispose_stage.dart';
import 'package:cobalt/src/errors/cobalt_error.dart';

/// Thrown when teardown finished but some of it did not go cleanly.
///
/// The scope is fully disposed by the time this is thrown. Teardown is
/// best-effort: a step that throws or runs past the deadline is recorded and
/// the rest still runs, so one broken object cannot strand everything
/// registered after it.
///
/// Steps that timed out were abandoned, not cancelled — Dart cannot cancel a
/// future — which is the main reason this is reported rather than swallowed.
final class CobaltDisposeError extends CobaltError {
  /// Creates an error describing every [failures] entry from [scopeName].
  CobaltDisposeError(this.scopeName, this.failures)
    : super(_describe(scopeName, failures));

  /// The scope whose teardown was incomplete.
  final String scopeName;

  /// Everything that did not complete, in teardown order.
  final List<CobaltDisposeFailure> failures;

  /// The subset that ran out of time rather than throwing.
  Iterable<CobaltDisposeFailure> get timeouts =>
      failures.where((failure) => failure.isTimeout);

  /// Whether any step ran past the deadline.
  bool get hasTimeout => failures.any((failure) => failure.isTimeout);

  /// The subset that is an initialization failure rather than a teardown one.
  ///
  /// Present only as context: an init failure alone never produces this error,
  /// because it was already delivered to whoever called `init()`.
  Iterable<CobaltDisposeFailure> get initFailures =>
      failures.where((failure) => failure.isInitFailure);

  /// The subset that is teardown proper — everything Cobalt could not release.
  Iterable<CobaltDisposeFailure> get releaseFailures =>
      failures.where((failure) => !failure.isInitFailure);

  static String _describe(String scope, List<CobaltDisposeFailure> failures) {
    final released = failures
        .where((failure) => failure.stage == CobaltDisposeStage.releasing)
        .length;
    final lines = failures.map((failure) => '  $failure').join('\n');
    final context = failures.length - released;
    final suffix = context == 0
        ? ''
        : ' The scope was never fully built; $context initialization '
              'failure(s) are listed for context.';
    return 'Disposing scope "$scope" could not release $released step(s).'
        '$suffix\n$lines';
  }
}
