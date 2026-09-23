import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:flow_scopes/features/cart/domain/cart_draft.dart';

/// What one run of the cart flow owns.
class CartFlowScope implements CobaltScopeBuilder {
  const CartFlowScope();

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<CartDraft>(const CartDraftFactory());
}
