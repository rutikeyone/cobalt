import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:flow_scopes/app/app_routes.dart';
import 'package:flow_scopes/features/cart/cart_step.dart';
import 'package:flow_scopes/features/cart/domain/cart_draft.dart';
import 'package:flow_scopes/l10n/flow_scopes_l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CartStepScreen extends StatelessWidget {
  const CartStepScreen({required this.step, super.key});

  final CartStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = FlowScopesL10n.of(context);
    final draft = context.cobalt<CartDraft>();
    final next = step.next;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (step) {
          CartStep.cart => l10n.stepCart,
          CartStep.checkout => l10n.stepCheckout,
          CartStep.payment => l10n.stepPayment,
        }),
      ),
      body: ListView(
        children: [
          ListTile(
            key: const Key('cart-scope'),
            title: Text(l10n.scopeLine(context.cobaltScope.name)),
            subtitle: Text(step.path),
          ),
          ListTile(
            key: Key('cart-draft-${step.name}'),
            title: const Text('get<CartDraft>()'),
            subtitle: Text(l10n.cartLine('${identityHashCode(draft)}')),
          ),
          const Divider(),
          if (next != null)
            ListTile(
              key: const Key('cart-next'),
              title: Text(
                next == CartStep.checkout
                    ? l10n.continueToCheckout
                    : l10n.continueToPayment,
              ),
              subtitle: Text(l10n.cartNextDetail),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(next.path),
            ),
          ListTile(
            key: const Key('cart-leave'),
            title: Text(l10n.leaveFlow),
            subtitle: Text(l10n.leaveFlowDetail),
            trailing: const Icon(Icons.logout),
            onTap: () => context.go(AppRoutes.home),
          ),
        ],
      ),
    );
  }
}
