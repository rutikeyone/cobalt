// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'flow_scopes_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class FlowScopesL10nKo extends FlowScopesL10n {
  FlowScopesL10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Cobalt · 플로우 스코프';

  @override
  String get whatIsAlive => '지금 살아 있는 것';

  @override
  String get openAFlow => '플로우 열기';

  @override
  String get openAFlowDetail => '들어갈 때 스코프가 생성되고 나갈 때 해제됩니다';

  @override
  String order(String id) {
    return '주문 $id';
  }

  @override
  String get workspaceTabs => '워크스페이스 (탭)';

  @override
  String get workspaceTabsDetail => '셸 스코프 하나와 탭마다 스코프 하나';

  @override
  String get eventLog => '이벤트 로그';

  @override
  String get logEmpty => '아직 아무것도 없습니다';

  @override
  String scopeBuilt(String subject) {
    return '$subject 스코프 빌드됨';
  }

  @override
  String scopeDisposed(String subject) {
    return '$subject 스코프 해제됨';
  }

  @override
  String draftCreated(String order) {
    return '초안 $order 생성됨';
  }

  @override
  String draftDisposed(String order) {
    return '초안 $order 해제됨';
  }

  @override
  String get scopeTree => '스코프 트리';

  @override
  String scopeNode(String state, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '하위 스코프 $count개',
      zero: '하위 스코프 없음',
    );
    return '$state · $_temp0';
  }

  @override
  String get checkoutFlow => '주문 플로우';

  @override
  String scopeLine(String name) {
    return '스코프: $name';
  }

  @override
  String draftLine(String order, String instance) {
    return '주문 $order · 인스턴스 $instance';
  }

  @override
  String get continueToPayment => '결제로 이동';

  @override
  String get continueToPaymentDetail => '같은 플로우이므로 초안이 유지되어야 합니다';

  @override
  String switchToOrder(String other) {
    return '주문 $other(으)로 전환';
  }

  @override
  String get switchToOrderDetail => 'identity가 바뀌어 새 스코프가 빌드됩니다';

  @override
  String get leaveFlow => '플로우 나가기';

  @override
  String get leaveFlowDetail => '스코프와 초안이 함께 사라집니다';

  @override
  String get workspace => '워크스페이스';

  @override
  String shellScope(String name) {
    return '셸 스코프: $name';
  }

  @override
  String markerLine(String label, String name) {
    return '$label · 스코프 $name';
  }

  @override
  String get tabsExplained =>
      '탭을 바꿨다가 돌아와도 아무것도 다시 빌드되지 않습니다. 브랜치는 보이지 않아도 살아 있으므로, 그 스코프는 워크스페이스 전체가 닫힐 때까지 유지됩니다.';

  @override
  String get tabFeed => '피드';

  @override
  String get tabProfile => '프로필';

  @override
  String get openCart => '장바구니 → 주문서 → 결제';

  @override
  String get openCartDetail => '최상위 라우트 세 개, 스코프 하나';

  @override
  String get cartCreated => '장바구니 초안 생성됨';

  @override
  String get cartDisposed => '장바구니 초안 해제됨';

  @override
  String get stepCart => '장바구니';

  @override
  String get stepCheckout => '주문서';

  @override
  String get stepPayment => '결제';

  @override
  String get continueToCheckout => '주문서로 이동';

  @override
  String get cartNextDetail => '다른 최상위 라우트이므로 초안이 유지되어야 합니다';

  @override
  String cartLine(String instance) {
    return '장바구니 초안 · 인스턴스 $instance';
  }
}
