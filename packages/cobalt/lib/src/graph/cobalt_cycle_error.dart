/// Thrown when dependencies form a cycle.
///
/// Raised in two places: while sorting the async init graph, and while
/// resolving at runtime, when a factory asks for something already being
/// built further up the same chain. Either way the error names the path
/// instead of deadlocking or overflowing the stack.
final class CobaltCycleError extends StateError {
  /// Creates an error describing [cycle].
  CobaltCycleError(this.cycle)
    : super('Dependency cycle detected: ${cycle.join(' -> ')}');

  /// The cycle, starting and ending at the same node.
  final List<String> cycle;
}
