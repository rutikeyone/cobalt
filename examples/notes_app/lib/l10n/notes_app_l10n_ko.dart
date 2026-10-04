// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'notes_app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class NotesL10nKo extends NotesL10n {
  NotesL10nKo([String locale = 'ko']) : super(locale);

  @override
  String get twoPhaseStartup => '두 단계 시작';

  @override
  String get restartGraph => '앱 스코프를 해제하고 새로 시작';

  @override
  String get phaseZero => '0단계: @CobaltBootstrap';

  @override
  String phaseZeroNote(String scope) {
    return '\"$scope\" 스코프가 맡으며, 그 스코프가 해제될 때 함께 해제됩니다';
  }

  @override
  String get phaseOne => '1단계: @CobaltInit';

  @override
  String get databaseOpen => '데이터베이스 열림';

  @override
  String get searchIndexBuilt => '검색 인덱스 빌드됨';

  @override
  String get telemetryStarted => '텔레메트리 시작됨';

  @override
  String statusLine(String label, String value) {
    return '$label: $value';
  }

  @override
  String apiLine(String url) {
    return 'api: $url';
  }

  @override
  String get sessionScope => '세션 스코프';

  @override
  String signedInAs(String name) {
    return '로그인됨: $name';
  }

  @override
  String get signedOut => '로그아웃됨';

  @override
  String scopeLine(String name) {
    return '스코프: $name';
  }

  @override
  String get noScope => '없음';

  @override
  String get signIn => '로그인';

  @override
  String get signOut => '로그아웃';

  @override
  String get recordActivity => '활동 기록';

  @override
  String activityCount(int count) {
    return '활동: $count';
  }

  @override
  String get sessionExplained =>
      '로그아웃하면 세션 스코프가 해제됩니다. 그 안에서 빌드된 모든 것이 함께 사라집니다. reset()을 구현하는 리포지토리도, 세션을 구독하는 곳도 없습니다.';

  @override
  String get propertyInjection => '프로퍼티 주입';

  @override
  String get search => '검색';

  @override
  String noteCount(int count) {
    return '개수: $count';
  }

  @override
  String newNote(int number) {
    return '메모 $number';
  }

  @override
  String get widgetOwnedScope => '위젯 소유 스코프';

  @override
  String get draft => '초안';

  @override
  String get untitled => '제목 없음';

  @override
  String get widgetScopeExplained =>
      '이 화면은 자체 스코프를 선언합니다. 화면을 떠나면 스코프가 해제되므로, 다른 곳에서 따로 신경 쓸 필요가 없습니다.';

  @override
  String get scopeTree => '스코프 트리';

  @override
  String get namedAndMulti => '이름 지정 주입과 다중 주입';

  @override
  String registrationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '등록 $count개',
    );
    return '$_temp0';
  }

  @override
  String get sampleNote => '장보기 목록';

  @override
  String get environments => '환경';

  @override
  String get activeEnvironment => '현재 환경';

  @override
  String apiClientLine(String implementation, String detail) {
    return '$implementation → $detail';
  }

  @override
  String get noNetwork => '네트워크 없음';

  @override
  String nothingRegistered(String environment) {
    return '등록 없음: \"$environment\" 환경을 선언한 구현이 없습니다';
  }

  @override
  String get crashReportingStep => 'report-crashes 부트스트랩 작업';

  @override
  String get stepRan => '실행됨';

  @override
  String get stepSkipped => '이 환경에서는 건너뜀';

  @override
  String get environmentsExplained =>
      '두 구현 모두 같은 exposeAs가 붙어 있습니다. 이 환경을 지정한 쪽만 등록되므로, 이를 쓰는 쪽은 어느 구현을 받았는지 알지 못합니다. 아무도 선언하지 않은 환경을 고르면 그 타입은 아예 없습니다. get<ApiClient>()는 잘못된 클래스를 돌려주는 대신 예외를 던집니다.';
}
