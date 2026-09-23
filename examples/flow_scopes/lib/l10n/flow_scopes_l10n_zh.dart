// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'flow_scopes_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class FlowScopesL10nZh extends FlowScopesL10n {
  FlowScopesL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Cobalt · 流程作用域';

  @override
  String get whatIsAlive => '此刻还活着什么';

  @override
  String get openAFlow => '打开一个流程';

  @override
  String get openAFlowDetail => '进入时创建作用域，离开时释放';

  @override
  String order(String id) {
    return '订单 $id';
  }

  @override
  String get workspaceTabs => '工作区（标签页）';

  @override
  String get workspaceTabsDetail => '一个外壳作用域，外加每个标签页一个';

  @override
  String get eventLog => '事件日志';

  @override
  String get logEmpty => '还没有任何内容';

  @override
  String scopeBuilt(String subject) {
    return '作用域 $subject 已构建';
  }

  @override
  String scopeDisposed(String subject) {
    return '作用域 $subject 已释放';
  }

  @override
  String draftCreated(String order) {
    return '草稿 $order 已创建';
  }

  @override
  String draftDisposed(String order) {
    return '草稿 $order 已释放';
  }

  @override
  String get scopeTree => '作用域树';

  @override
  String scopeNode(String state, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个子作用域',
      zero: '没有子作用域',
    );
    return '$state · $_temp0';
  }

  @override
  String get checkoutFlow => '结算流程';

  @override
  String scopeLine(String name) {
    return '作用域：$name';
  }

  @override
  String draftLine(String order, String instance) {
    return '订单 $order · 实例 $instance';
  }

  @override
  String get continueToPayment => '继续去付款';

  @override
  String get continueToPaymentDetail => '同一个流程 —— 草稿必须活下来';

  @override
  String switchToOrder(String other) {
    return '切换到订单 $other';
  }

  @override
  String get switchToOrderDetail => 'identity 变了 —— 会构建一个新的作用域';

  @override
  String get leaveFlow => '离开这个流程';

  @override
  String get leaveFlowDetail => '作用域和草稿都随它一起消失';

  @override
  String get workspace => '工作区';

  @override
  String shellScope(String name) {
    return '外壳作用域：$name';
  }

  @override
  String markerLine(String label, String name) {
    return '$label · 作用域 $name';
  }

  @override
  String get tabsExplained =>
      '切走再切回来：什么都不会重建。分支保持存活而非保持可见，所以它的作用域会一直活到整个工作区关闭。';

  @override
  String get tabFeed => '动态';

  @override
  String get tabProfile => '个人资料';

  @override
  String get openCart => '购物车 → 结算 → 付款';

  @override
  String get openCartDetail => '三条顶层路由，一个作用域';

  @override
  String get cartCreated => '购物车草稿已创建';

  @override
  String get cartDisposed => '购物车草稿已释放';

  @override
  String get stepCart => '购物车';

  @override
  String get stepCheckout => '结算';

  @override
  String get stepPayment => '付款';

  @override
  String get continueToCheckout => '继续去结算';

  @override
  String get cartNextDetail => '另一条顶层路由 —— 草稿必须活下来';

  @override
  String cartLine(String instance) {
    return '购物车草稿 · 实例 $instance';
  }
}
