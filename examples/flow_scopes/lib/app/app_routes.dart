/// Every path the example can be at.
class AppRoutes {
  const AppRoutes._();

  static const home = '/';
  static const scopeTree = '/scope-tree';

  /// The tabbed workspace — a shell scope with a scope per tab.
  static const workspaceFeed = '/workspace/feed';
  static const workspaceProfile = '/workspace/profile';

  /// The cart flow — three top-level routes under one shell.
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const cartPayment = '/payment';

  /// The flow itself — `/orders/:orderId/summary` and `.../payment`.
  static String summary(String orderId) => '/orders/$orderId/summary';

  static String payment(String orderId) => '/orders/$orderId/payment';
}
