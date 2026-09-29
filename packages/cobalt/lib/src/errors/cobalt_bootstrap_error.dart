import 'package:cobalt/src/errors/cobalt_error.dart';

/// Thrown when a phase-0 bootstrap step fails.
///
/// Wrapping the original failure keeps the name of the step that broke, which
/// is otherwise lost by the time the error reaches the caller. Startup stops
/// at the first failure — later steps do not run, and the container is never
/// assembled.
final class CobaltBootstrapError extends CobaltError {
  /// Wraps [cause] thrown by the bootstrap step called [step].
  CobaltBootstrapError(this.step, this.cause, this.causeStackTrace)
    : super('Bootstrap step "$step" failed: $cause');

  /// The `name` reported by the failing step.
  final String step;

  /// The original error the step threw.
  final Object cause;

  /// The stack trace captured where [cause] was thrown.
  final StackTrace causeStackTrace;
}
