import 'package:flow_scopes/app/app_routes.dart';

/// The three screens of the cart flow, in order.
enum CartStep {
  cart(AppRoutes.cart),
  checkout(AppRoutes.checkout),
  payment(AppRoutes.cartPayment);

  const CartStep(this.path);

  /// Where the screen lives.
  final String path;

  /// The step after this one, or null for the last.
  CartStep? get next => switch (this) {
    cart => checkout,
    checkout => payment,
    payment => null,
  };
}
