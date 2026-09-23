// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'flow_scopes_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class FlowScopesL10nRu extends FlowScopesL10n {
  FlowScopesL10nRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Cobalt · скоупы флоу';

  @override
  String get whatIsAlive => 'что живо прямо сейчас';

  @override
  String get openAFlow => 'Открыть флоу';

  @override
  String get openAFlowDetail =>
      'скоуп создаётся на входе и разбирается на выходе';

  @override
  String order(String id) {
    return 'Заказ $id';
  }

  @override
  String get workspaceTabs => 'Рабочее пространство (вкладки)';

  @override
  String get workspaceTabsDetail => 'скоуп-шелл плюс скоуп на каждую вкладку';

  @override
  String get eventLog => 'Журнал событий';

  @override
  String get logEmpty => 'пока ничего';

  @override
  String scopeBuilt(String subject) {
    return 'скоуп $subject построен';
  }

  @override
  String scopeDisposed(String subject) {
    return 'скоуп $subject разобран';
  }

  @override
  String draftCreated(String order) {
    return 'черновик $order создан';
  }

  @override
  String draftDisposed(String order) {
    return 'черновик $order разобран';
  }

  @override
  String get scopeTree => 'Дерево скоупов';

  @override
  String scopeNode(String state, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дочерних',
      many: '$count дочерних',
      few: '$count дочерних',
      one: '$count дочерний',
      zero: 'нет дочерних',
    );
    return '$state · $_temp0';
  }

  @override
  String get checkoutFlow => 'Флоу оформления';

  @override
  String scopeLine(String name) {
    return 'скоуп: $name';
  }

  @override
  String draftLine(String order, String instance) {
    return 'заказ $order · инстанс $instance';
  }

  @override
  String get continueToPayment => 'Перейти к оплате';

  @override
  String get continueToPaymentDetail => 'тот же флоу — черновик обязан выжить';

  @override
  String switchToOrder(String other) {
    return 'Перейти к заказу $other';
  }

  @override
  String get switchToOrderDetail => 'identity сменилась — строится новый скоуп';

  @override
  String get leaveFlow => 'Выйти из флоу';

  @override
  String get leaveFlowDetail => 'скоуп и черновик уходят вместе с ним';

  @override
  String get workspace => 'Рабочее пространство';

  @override
  String shellScope(String name) {
    return 'скоуп шелла: $name';
  }

  @override
  String markerLine(String label, String name) {
    return '$label · скоуп $name';
  }

  @override
  String get tabsExplained =>
      'Переключите вкладку и вернитесь: ничего не пересобирается. Ветка держится живой, а не видимой, поэтому её скоуп живёт, пока не закроется всё рабочее пространство.';

  @override
  String get tabFeed => 'Лента';

  @override
  String get tabProfile => 'Профиль';

  @override
  String get openCart => 'Корзина → оформление → оплата';

  @override
  String get openCartDetail => 'три маршрута верхнего уровня, один скоуп';

  @override
  String get cartCreated => 'черновик корзины создан';

  @override
  String get cartDisposed => 'черновик корзины разобран';

  @override
  String get stepCart => 'Корзина';

  @override
  String get stepCheckout => 'Оформление';

  @override
  String get stepPayment => 'Оплата';

  @override
  String get continueToCheckout => 'Перейти к оформлению';

  @override
  String get cartNextDetail =>
      'другой маршрут верхнего уровня — черновик обязан выжить';

  @override
  String cartLine(String instance) {
    return 'черновик корзины · инстанс $instance';
  }
}
