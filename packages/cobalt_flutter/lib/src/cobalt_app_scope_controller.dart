/// Restarts the root scope a [CobaltAppScope] owns.
///
/// Reach it with `CobaltAppScope.of(context)`.
abstract interface class CobaltAppScopeController {
  /// Disposes the current root scope and builds a new one.
  ///
  /// The same operation retries a startup that failed — there is nothing to
  /// dispose in that case, so it simply starts again. While it runs the tree
  /// shows the widget's `loading`.
  ///
  /// The returned future completes once the new scope is ready, or once the
  /// attempt has failed and the error is on screen.
  Future<void> restart();
}
