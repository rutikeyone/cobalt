/// Prepared asynchronously before the scope reports itself active.
///
/// A class annotated `@CobaltInit` implements this; the generated factory
/// awaits [init] before the instance becomes resolvable. In Manual Mode the
/// same contract is expressed by a `CobaltAsyncFactory` that awaits [init]
/// itself.
abstract interface class AsyncInitializable {
  /// Performs the asynchronous part of construction.
  Future<void> init();
}
