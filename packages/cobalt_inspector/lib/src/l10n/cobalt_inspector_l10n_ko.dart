// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'cobalt_inspector_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class CobaltInspectorL10nKo extends CobaltInspectorL10n {
  CobaltInspectorL10nKo([String locale = 'ko']) : super(locale);

  @override
  String get inspectorTitle => 'Cobalt · 인스펙터';

  @override
  String get pauseTooltip => '갱신 일시 중지';

  @override
  String get resumeTooltip => '그래프 다시 따라가기';

  @override
  String get clearTooltip => '기록된 내용 지우기';

  @override
  String get tabTree => '트리';

  @override
  String get tabBuilt => '빌드됨';

  @override
  String get tabLog => '로그';

  @override
  String get logSearchHint => '메시지, 스코프 또는 키로 필터';

  @override
  String get logEmpty => '아직 보고된 내용이 없습니다';

  @override
  String get logNoMatch => '일치하는 항목이 없습니다';

  @override
  String get filterAll => '전체';

  @override
  String get familyScope => '스코프';

  @override
  String get familyStartup => '시작';

  @override
  String get familyInstance => '인스턴스';

  @override
  String get familyFailure => '실패';

  @override
  String get treeSearchHint => '등록 필터';

  @override
  String get collapseAll => '모두 접기';

  @override
  String get expandAll => '모두 펼치기';

  @override
  String get treeNothingRegistered => '등록 없음';

  @override
  String get treeNoMatch => '일치 항목 없음';

  @override
  String treeHooks(String hooks) {
    return '훅: $hooks';
  }

  @override
  String get groupingFlat => '목록';

  @override
  String get groupingByScope => '스코프별';

  @override
  String get groupingByLifetime => '수명별';

  @override
  String get groupingSlowest => '느린 순';

  @override
  String get builtEmpty => '아직 빌드된 인스턴스가 없습니다';

  @override
  String builtWhere(String scope, String ownership) {
    return '\"$scope\"에서 · $ownership';
  }

  @override
  String get ownedByScope => '스코프와 함께 해제';

  @override
  String get ownedByCaller => '호출자 소유';

  @override
  String get lifetimeGone => '사라짐';

  @override
  String get badgeOverridden => '재정의됨';

  @override
  String get badgeDecorated => '데코레이트됨';

  @override
  String get copyRecord => '이 기록 복사';

  @override
  String get recordCopied => '기록을 복사했습니다';

  @override
  String get fieldLevel => '레벨';

  @override
  String get fieldScope => '스코프';

  @override
  String get fieldKey => '키';

  @override
  String get fieldLifetime => '수명';

  @override
  String get fieldRetained => '보유 여부';

  @override
  String get fieldError => '오류';

  @override
  String get fieldStack => '스택';

  @override
  String get fieldStructured => '구조화';

  @override
  String get factOwnedBy => '소유 스코프';

  @override
  String get factReached => '접근 경로';

  @override
  String get reachedInherited => '상위 스코프에서 상속됨';

  @override
  String get reachedHere => '이 스코프에 등록됨';

  @override
  String get factReplaced => '대체';

  @override
  String get replacedByOverride => '재정의로 대체됨, 실제 등록은 건너뜀';

  @override
  String get factDecoratedBy => '데코레이터';

  @override
  String get factImplementation => '빌드 클래스';

  @override
  String get factBuildTime => '마지막 빌드 시간';

  @override
  String withoutDependencies(String time) {
    return '의존성 제외 $time';
  }

  @override
  String withDependencies(String time) {
    return '의존성 포함 $time';
  }

  @override
  String get factTornDown => '스코프와 함께 해제';

  @override
  String get tornDownYes => '예';

  @override
  String get tornDownNo => '아니요, 호출자 소유';

  @override
  String get tornDownUnknown => '알 수 없음';

  @override
  String get factBuilt => '빌드됨';

  @override
  String get factFailed => '실패';

  @override
  String get buildItTitle => '지금 빌드';

  @override
  String get buildItSubtitle => '인스턴스를 실제로 생성하고 로그에 남깁니다. 보고 있는 그래프가 바뀝니다';

  @override
  String get notBuildable => '매개변수가 필요해서 여기서 빌드할 수 없습니다';

  @override
  String nodeCounts(int registrations, int children) {
    String _temp0 = intl.Intl.pluralLogic(
      children,
      locale: localeName,
      other: '하위 스코프 $children개',
    );
    return '등록 $registrations개 · $_temp0';
  }
}
