// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'gallery_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class GalleryL10nKo extends GalleryL10n {
  GalleryL10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Cobalt 예제';

  @override
  String get tagline => '의존성 주입 · 예제';

  @override
  String get lede => '기능마다 예제 하나. 대부분은 바로 여기서 열리고, 출력만 하는 예제는 대신 그 출력을 보여 줍니다.';

  @override
  String get languageTooltip => '언어';

  @override
  String get allExamples => '전체 예제';

  @override
  String get whatItShows => '보여 주는 것';

  @override
  String get openExample => '예제 열기';

  @override
  String get copyCommand => '명령 복사';

  @override
  String get commandCopied => '명령을 복사했습니다';

  @override
  String get kindScreen => '화면';

  @override
  String get kindTerminal => '터미널';

  @override
  String get whereItLives => '코드 위치';

  @override
  String get consoleOutput => '콘솔 출력';

  @override
  String get testOutput => '테스트 출력';

  @override
  String get sectionStartup => '시작';

  @override
  String get sectionStartupBlurb => '그래프를 띄우고, 어떤 그래프를 띄울지 고르기';

  @override
  String get sectionInjection => '주입';

  @override
  String get sectionInjectionBlurb => '필요한 곳에 의존성을 전달하기';

  @override
  String get sectionScopes => '스코프와 수명';

  @override
  String get sectionScopesBlurb => '그래프가 언제 생기고 언제 사라지는지';

  @override
  String get sectionCodegen => '코드 생성';

  @override
  String get sectionCodegenBlurb => '제너레이터가 작성하는 코드, 그리고 같은 코드를 직접 작성하기';

  @override
  String get sectionObservability => '관측성';

  @override
  String get sectionObservabilityBlurb => '그래프가 하는 일 지켜보기';

  @override
  String get sectionTesting => '테스트';

  @override
  String get sectionTestingBlurb => '의존성 교체하기, 그리고 함정';

  @override
  String get startupTitle => '두 단계 시작';

  @override
  String get startupTeaches =>
      '부트스트랩 작업은 컨테이너가 생기기 전에 실행되고, 비동기 초기화는 그래프 순서로 실행됩니다.';

  @override
  String get startupPoint1 => '0단계 작업은 루트 스코프가 맡으며 루트 스코프와 함께 해제됩니다';

  @override
  String get startupPoint2 => '무언가를 연 작업은 그 위에 빌드된 모든 것보다 나중에, 마지막으로 닫힙니다';

  @override
  String get startupPoint3 =>
      '1단계는 @CobaltInit을 그래프로 기다리므로, 서로 독립된 브랜치는 함께 실행됩니다';

  @override
  String get startupPoint4 => '순서는 dependsOn이 정합니다. 실행 순서를 직접 작성할 일은 없습니다';

  @override
  String get environmentsTitle => '환경';

  @override
  String get environmentsTeaches => '인터페이스 하나, 빌드마다 다른 구현.';

  @override
  String get environmentsPoint1 =>
      '@CobaltEnvironment는 목록을 받지 않고 여러 번 붙입니다. 등록은 집합에 속하고, 시작할 때는 그중 하나를 고릅니다';

  @override
  String get environmentsPoint2 => '환경이 겹치는 두 등록은 앱이 아니라 빌드를 실패시킵니다';

  @override
  String get environmentsPoint3 =>
      '아무것도 고르지 않으면 나뉜 타입이 등록되지 않으므로, 누락이 분명하게 드러납니다';

  @override
  String get environmentsPoint4 => '수동 모드는 제너레이터가 내보내는 것과 같은 `if`를 작성합니다';

  @override
  String get lazyAsyncTitle => '지연 비동기';

  @override
  String get lazyAsyncTeaches => '비용이 큰 객체를 시작할 때가 아니라, 처음 요청하는 화면이 빌드합니다.';

  @override
  String get lazyAsyncPoint1 =>
      'registerLazyAsyncSingleton 또는 @CobaltInit(lazy: true)은 이를 init()에서 빼므로, 시작 과정은 이를 기다리지 않습니다';

  @override
  String get lazyAsyncPoint2 =>
      '첫 getAsync가 빌드하고, 동시에 요청한 호출자는 모두 그 한 번의 빌드를 기다립니다';

  @override
  String get lazyAsyncPoint3 =>
      'CobaltAsyncBuilder는 로딩을 한 번만 보여 줍니다. 나중에 연 화면은 바로 렌더링합니다';

  @override
  String get lazyAsyncPoint4 => '실패한 빌드는 기억되지 않으므로, 다시 시도하면 다시 빌드합니다';

  @override
  String get lazyAsyncStarted => '시작 완료';

  @override
  String get lazyAsyncOpen => '검색 열기';

  @override
  String get lazyAsyncOpenDetail => '첫 방문에서 엔진을 빌드하고, 이후 방문에서는 이미 빌드된 엔진을 씁니다';

  @override
  String get lazyAsyncWarmUp => '워밍업';

  @override
  String get lazyAsyncWarmUpDetail => 'scope.warmUp이 지금 빌드하므로, 검색이 기다림 없이 열립니다';

  @override
  String get lazyAsyncSearchTitle => '검색';

  @override
  String get lazyAsyncBuilding => '엔진 빌드 중…';

  @override
  String lazyAsyncBuilds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '엔진 빌드 $count회',
      zero: '엔진이 아직 빌드되지 않음',
    );
    return '$_temp0';
  }

  @override
  String lazyAsyncReady(String instance) {
    return '엔진 준비됨 · 인스턴스 $instance';
  }

  @override
  String get asyncTransientTitle => '비동기 트랜지언트';

  @override
  String get asyncTransientTeaches =>
      'I/O로 빌드되고 호출자마다 새것이 필요한 객체. 요청할 때마다 만드는 보고서처럼.';

  @override
  String get asyncTransientPoint1 =>
      'registerAsyncFactory, 또는 @CobaltInit 클래스에 붙인 @cobaltTransient는 getAsync마다 새로 빌드합니다';

  @override
  String get asyncTransientPoint2 =>
      'init()은 이를 빌드하지 않고 스코프도 보유하지 않습니다. 받은 것은 호출자가 소유합니다';

  @override
  String get asyncTransientPoint3 =>
      '동시에 한 호출은 빌드를 공유하지 않습니다. 동시에 두 번이면 빌드도 두 번입니다';

  @override
  String get asyncTransientPoint4 =>
      'get은 getAsync를 안내하는 CobaltAsyncTransientError를 던지고, dependsOn은 이를 기다릴 수 없습니다';

  @override
  String get asyncTransientStarted => '시작 완료';

  @override
  String get asyncTransientOne => '보고서 빌드';

  @override
  String get asyncTransientOneDetail => 'getAsync마다 새로 빌드합니다';

  @override
  String get asyncTransientTwo => '동시에 두 번 요청';

  @override
  String get asyncTransientTwoDetail => '동시 호출은 빌드를 공유하지 않습니다';

  @override
  String asyncTransientBuilds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '보고서 $count개 빌드됨',
      zero: '아직 빌드된 보고서 없음',
    );
    return '$_temp0';
  }

  @override
  String asyncTransientReceived(int number, String instance) {
    return '보고서 #$number · 인스턴스 $instance';
  }

  @override
  String get propertyTitle => '프로퍼티 주입';

  @override
  String get propertyTeaches => '생성자는 비어 있고 필드는 그래프가 채우는 컨트롤러.';

  @override
  String get propertyPoint1 => '믹스인은 클래스 옆에 생성되며, 생성 후 필드를 채웁니다';

  @override
  String get propertyPoint2 => '필드는 private이어도 됩니다. part 파일은 같은 라이브러리에 있습니다';

  @override
  String get propertyPoint3 =>
      'late final이 강제되므로, 두 번째 할당은 의존성을 조용히 바꾸지 않고 예외를 던집니다';

  @override
  String get propertyPoint4 => '생성자 인자 다섯 개에서 열네 개를 없애 주는 것이 바로 이것입니다';

  @override
  String get namedTitle => '이름 지정 주입과 다중 주입';

  @override
  String get namedTeaches => '인터페이스 하나 뒤의 여러 구현을 이름으로 구분합니다.';

  @override
  String get namedPoint1 => '@Named는 등록이 여러 개인 타입에서 하나를 고릅니다';

  @override
  String get namedPoint2 => 'getAll은 한 타입의 모든 등록을 등록 순서대로 반환합니다';

  @override
  String get namedPoint3 => '한 스코프 안에서 같은 키가 중복되면 오류입니다. 마지막 것이 조용히 이기지 않습니다';

  @override
  String get decoratorsTitle => '데코레이터';

  @override
  String get decoratorsTeaches => '클래스를 건드리지 않고 등록이 내주는 객체를 감쌉니다. 캐시나 로그처럼.';

  @override
  String get decoratorsPoint1 =>
      'scope.decorate는 등록 하나를, decorateAll은 한 타입의 모든 등록을 감쌉니다. @CobaltDecorates(allNames: true)도 됩니다';

  @override
  String get decoratorsPoint2 =>
      '먼저 추가한 데코레이터가 가장 안쪽입니다. 키 하나든 타입 전체든 같으므로, 여기서 로그는 캐시된 응답을 봅니다';

  @override
  String get decoratorsPoint3 =>
      '보유되는 등록은 한 번만 데코레이트되어 공유되고, 스코프는 안쪽 인스턴스만 닫습니다';

  @override
  String get decoratorsPoint4 =>
      '재정의는 대체한 등록과 똑같이 데코레이트됩니다. 생성된 데코레이터는 @injected 필드를 받을 수 있습니다';

  @override
  String get decoratorsChain => '감싼 순서, 안쪽부터';

  @override
  String get decoratorsBackupChain => '예비 관측소, 이름 지정';

  @override
  String decoratorsAskBackup(String city) {
    return '$city 예비 예보';
  }

  @override
  String decoratorsAsk(String city) {
    return '$city 날씨 예보';
  }

  @override
  String decoratorsStationCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count회 호출됨',
      zero: '아직 호출되지 않음',
    );
    return '$_temp0';
  }

  @override
  String get widgetScopeTitle => '위젯 소유 스코프';

  @override
  String get widgetScopeTeaches => '딱 한 화면만큼 사는 그래프.';

  @override
  String get widgetScopePoint1 =>
      'CobaltScopedStatefulWidget은 자신이 소유한 스코프에 등록합니다';

  @override
  String get widgetScopePoint2 => '화면을 떠나면 화면이 빌드한 모든 것이 해제됩니다';

  @override
  String get widgetScopePoint3 => 'registerParamFactory는 값을 생성 과정에 전달합니다';

  @override
  String get widgetScopePoint4 => '부모 그래프는 그대로입니다. 이것은 변경이 아니라 하위 스코프입니다';

  @override
  String get sessionTitle => '세션 스코프';

  @override
  String get sessionTeaches => '로그아웃은 dispose() 한 번이 전부입니다.';

  @override
  String get sessionPoint1 => '세션이 빌드한 모든 것이 세션 스코프와 함께 사라집니다';

  @override
  String get sessionPoint2 => 'reset()을 구현하는 리포지토리도, 세션을 구독하는 곳도 없습니다';

  @override
  String get sessionPoint3 => '이것이 평평한 스택 대신 스코프 트리를 택하는 이유입니다';

  @override
  String get scopeTreeTitle => '스코프 트리';

  @override
  String get scopeTreeTeaches => '스코프 자체에서 렌더링한 실시간 계층 구조.';

  @override
  String get scopeTreePoint1 =>
      'CobaltScope.children이 공개되어 있어, 런타임에 트리를 살펴볼 수 있습니다';

  @override
  String get scopeTreePoint2 => '예제 두 개를 열어도 트리는 서로 무관합니다. 각자 자기 루트가 있습니다';

  @override
  String get scopeTreePoint3 => '깊이와 부모는 스코프에 있고, 진단은 바로 그것을 읽습니다';

  @override
  String get flowTitle => '내비게이션 플로우';

  @override
  String get flowTeaches => '내비게이션 플로우가 열려 있는 동안만 사는 스코프.';

  @override
  String get flowPoint1 => 'CobaltShellRoute: 플로우에 들어가면 스코프가 생기고, 나가면 사라집니다';

  @override
  String get flowPoint2 => '플로우의 대상이 바뀌면 identity가 스코프를 다시 빌드합니다';

  @override
  String get flowPoint3 => '탭: 브랜치는 보이지 않아도 살아 있으므로, 전환해도 아무것도 해제되지 않습니다';

  @override
  String get flowPoint4 => '라우터 리스너는 어디에도 없습니다. 소유권은 위젯 트리에 있습니다';

  @override
  String get teardownTitle => '해제';

  @override
  String get teardownTeaches => '해제가 실제로 보장하는 것: 순서, 실패, 타임아웃, adopt().';

  @override
  String get teardownPoint1 => '선언 순서가 아니라 생성 순서의 역순(LIFO)입니다';

  @override
  String get teardownPoint2 => '예외를 던진 dispose는 기록되고, 나머지는 그대로 실행됩니다';

  @override
  String get teardownPoint3 => '멈춘 dispose는 기한에 걸려 보고되며, 끝없이 기다리지 않습니다';

  @override
  String get teardownPoint4 => 'adopt()는 의존성이 아닌 객체의 수명을 스코프에 묶습니다';

  @override
  String get codegenTitle => '생성된 컨테이너';

  @override
  String get codegenTeaches => '가장 작은 코드 생성 설정과, 그것이 작성하는 코드.';

  @override
  String get codegenPoint1 => '클래스에 @cobaltInject를 붙이면 lib/cobalt.g.dart가 생깁니다';

  @override
  String get codegenPoint2 => '출력에는 이름 있는 const 팩토리 클래스만 있고, 클로저는 없습니다';

  @override
  String get codegenPoint3 => '등록 순서는 컴파일 타임 위상 정렬로 정해집니다';

  @override
  String get codegenPoint4 => '의존성 순환은 그 순환을 지목하며 빌드를 실패시킵니다';

  @override
  String get manualTitle => '수동 모드';

  @override
  String get manualTeaches => '코드 생성도 Flutter도 없는 같은 그래프.';

  @override
  String get manualPoint1 => '제너레이터가 작성하는 것이 정확히 이것이며, 공개 API만 사용합니다';

  @override
  String get manualPoint2 => '순수 Dart: CLI, 서버, 일반 테스트에서 실행됩니다';

  @override
  String get manualPoint3 => 'CobaltScopeBuilder는 조합할 수 있고, 이것이 모듈을 대신합니다';

  @override
  String get manualPoint4 =>
      '코드 생성에 여기서 표현할 수 없는 것이 필요해진다면, 그것은 이름만 같은 두 프레임워크입니다';

  @override
  String get eventsTitle => '그래프 이벤트';

  @override
  String get eventsTeaches => '그래프가 스스로를 보고하고, 이미 쓰고 있는 로거로 흘려보냅니다.';

  @override
  String get eventsPoint1 => 'CobaltObserver 이벤트: 스코프 푸시, 인스턴스 빌드, 해제 실패';

  @override
  String get eventsPoint2 => 'talker, logging, logger 등 어떤 로거든 한 줄로 연결합니다';

  @override
  String get eventsPoint3 =>
      'CobaltMultiSink는 기록을 여러 곳에 나눠 보내고, 한 싱크가 실패해도 나머지는 계속 받습니다';

  @override
  String get eventsPoint4 => '의존성 해석은 일부러 보고하지 않습니다. 캐시 적중이 핫 패스이기 때문입니다';

  @override
  String get inspectorTitle => '앱 내 인스펙터';

  @override
  String get inspectorTeaches =>
      '실시간 트리와 무엇이 어떤 수명으로 빌드되었는지를 앱 안의 화면에서 보여 줍니다.';

  @override
  String get inspectorPoint1 => '트리는 이벤트로 재구성하지 않고, 살아 있는 스코프를 직접 순회해 얻습니다';

  @override
  String get inspectorPoint2 => '모든 등록은 자신의 수명을 지니며, debugKindOf로 읽습니다';

  @override
  String get inspectorPoint3 => '탭하면 사실만 보여 줍니다. 빌드는 별도의 동작이며 그 비용을 알려 줍니다';

  @override
  String get inspectorPoint4 => '즉시 생성 싱글턴은 트리에는 보이지만 빌드됨 목록에는 나타나지 않습니다';

  @override
  String get testingTitle => '테스트 패턴';

  @override
  String get testingTeaches => '테스트에서 의존성 재정의하기, 그리고 함정.';

  @override
  String get testingPoint1 => '하위 스코프를 푸시하고 다시 등록해서 재정의합니다. 변경이 아니라 섀도잉입니다';

  @override
  String get testingPoint2 =>
      '그래프는 setUp에서 빌드합니다. testWidgets는 fake-async 존 안에서 실행됩니다';

  @override
  String get testingPoint3 => '전역 컨테이너가 없으므로, 한 테스트가 다음 테스트로 새어 나가지 않습니다';

  @override
  String get testingPoint4 => '한 스코프 안의 중복은 오류입니다. 하위 스코프에서의 섀도잉이 지원되는 방법입니다';

  @override
  String get demoTitle => 'Cobalt · 인스펙터';

  @override
  String get demoInspect => '그래프 살펴보기';

  @override
  String get demoOpenSession => '세션 스코프 열기';

  @override
  String get demoOpenSessionHint => '푸시 1회, 비동기 초기화 1회, 인스턴스 몇 개';

  @override
  String get demoCloseSession => '세션 닫기';

  @override
  String get demoNothingOpen => '열린 것이 없습니다';

  @override
  String get demoTearsItDown => '스코프를 해제합니다';

  @override
  String get demoThenOpen => '그다음 앱 바에서 인스펙터를 여세요';

  @override
  String get demoThenOpenHint => '트리, 빌드된 것, 보고된 모든 내용';

  @override
  String get hostFailed => '이 예제를 시작하지 못했습니다';

  @override
  String get hostRetry => '다시 시도';
}
