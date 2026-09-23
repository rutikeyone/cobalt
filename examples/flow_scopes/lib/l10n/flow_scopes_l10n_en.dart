// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'flow_scopes_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class FlowScopesL10nEn extends FlowScopesL10n {
  FlowScopesL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cobalt · flow scopes';

  @override
  String get whatIsAlive => 'what is alive right now';

  @override
  String get openAFlow => 'Open a flow';

  @override
  String get openAFlowDetail =>
      'the scope is created on entry and disposed on exit';

  @override
  String order(String id) {
    return 'Order $id';
  }

  @override
  String get workspaceTabs => 'Workspace (tabs)';

  @override
  String get workspaceTabsDetail => 'a shell scope plus a scope per tab';

  @override
  String get eventLog => 'Event log';

  @override
  String get logEmpty => 'nothing yet';

  @override
  String scopeBuilt(String subject) {
    return '$subject scope built';
  }

  @override
  String scopeDisposed(String subject) {
    return '$subject scope disposed';
  }

  @override
  String draftCreated(String order) {
    return 'draft $order created';
  }

  @override
  String draftDisposed(String order) {
    return 'draft $order disposed';
  }

  @override
  String get scopeTree => 'Scope tree';

  @override
  String scopeNode(String state, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count children',
      one: '1 child',
      zero: 'no children',
    );
    return '$state · $_temp0';
  }

  @override
  String get checkoutFlow => 'Checkout flow';

  @override
  String scopeLine(String name) {
    return 'scope: $name';
  }

  @override
  String draftLine(String order, String instance) {
    return 'order $order · instance $instance';
  }

  @override
  String get continueToPayment => 'Continue to payment';

  @override
  String get continueToPaymentDetail => 'same flow — the draft must survive';

  @override
  String switchToOrder(String other) {
    return 'Switch to order $other';
  }

  @override
  String get switchToOrderDetail => 'identity changes — a new scope is built';

  @override
  String get leaveFlow => 'Leave the flow';

  @override
  String get leaveFlowDetail => 'the scope and the draft go with it';

  @override
  String get workspace => 'Workspace';

  @override
  String shellScope(String name) {
    return 'shell scope: $name';
  }

  @override
  String markerLine(String label, String name) {
    return '$label · scope $name';
  }

  @override
  String get tabsExplained =>
      'Switch tabs and come back: nothing is rebuilt. A branch is kept alive, not kept visible, so its scope lives until the whole workspace closes.';

  @override
  String get tabFeed => 'Feed';

  @override
  String get tabProfile => 'Profile';

  @override
  String get openCart => 'Cart → checkout → payment';

  @override
  String get openCartDetail => 'three top-level routes, one scope';

  @override
  String get cartCreated => 'cart draft created';

  @override
  String get cartDisposed => 'cart draft disposed';

  @override
  String get stepCart => 'Cart';

  @override
  String get stepCheckout => 'Checkout';

  @override
  String get stepPayment => 'Payment';

  @override
  String get continueToCheckout => 'Continue to checkout';

  @override
  String get cartNextDetail =>
      'another top-level route — the draft must survive';

  @override
  String cartLine(String instance) {
    return 'cart draft · instance $instance';
  }
}
