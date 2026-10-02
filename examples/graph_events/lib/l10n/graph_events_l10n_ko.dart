// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'graph_events_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class GraphEventsL10nKo extends GraphEventsL10n {
  GraphEventsL10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Cobalt · 관측성';

  @override
  String get liveLog => '실시간 로그';

  @override
  String get everyEvent => '아래 이벤트는 모두 그래프가 스스로 보고한 것입니다';

  @override
  String get everyEventDetail =>
      'CobaltTalkerObserver는 종류마다 별도의 제목으로 기록하므로, 로그 화면에서 종류별로 나누어 필터링할 수 있습니다.';

  @override
  String get openSession => '세션 스코프 열기';

  @override
  String get openSessionDetail => '푸시 1회, 비동기 초기화 1회, 인스턴스 몇 개';

  @override
  String get openBrokenSession => '닫히지 않는 스코프 열기';

  @override
  String get openBrokenSessionDetail => '해제할 때 일부러 예외를 던집니다';

  @override
  String get closeSession => '세션 닫기';

  @override
  String get nothingOpen => '열린 것이 없습니다';

  @override
  String scopeNamed(String name) {
    return '스코프 \"$name\"';
  }

  @override
  String get eventsRecorded => '기록된 이벤트';

  @override
  String get noFailures => '보고된 실패가 없습니다';

  @override
  String get noFailuresDetail => '닫히지 않는 세션을 닫아 보세요';

  @override
  String reportSummary(String kind, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '브레드크럼 $count개',
    );
    return '$kind · $_temp0';
  }
}
