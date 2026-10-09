<p align="center">
  <a href="GUIDE_MANUAL.md">English</a> · <a href="GUIDE_MANUAL.ru.md">Русский</a> · <a href="GUIDE_MANUAL.zh-CN.md">中文</a> · <a href="GUIDE_MANUAL.ko.md">한국어</a>
</p>

> 이 문서는 [GUIDE_MANUAL.md](GUIDE_MANUAL.md)를 번역한 것입니다. 영어판이 기준이며, 내용이 다르면 영어판을 따릅니다.

# Manual Mode (수동 모드)

코드 생성 없는 Cobalt입니다. 어노테이션도, `build_runner`도 없고, 생성되는 것도 커밋할 것도 없습니다.
등록은 여러분이 작성하며, 런타임은 제너레이터가 대상으로 삼는 바로 그 런타임입니다.

이것은 축소판이 아니라 프레임워크 전체입니다. 제너레이터가 내보내는 모든 것은 이 문서가 설명하는 것만으로
작성되며, 이것이 프로젝트의 변함없는 불변 조건입니다. 코드 생성에 Manual Mode로 표현할 수 없는 것이
필요해지는 순간, 이것은 이름만 같은 두 프레임워크가 됩니다.

이 모드는 기존 컨테이너를 점진적으로 마이그레이션할 때, 그래프가 작아서 빌드 단계를 둘 가치가 없을 때,
또는 빌드 단계를 아예 둘 수 없는 패키지에서 작업할 때 사용하십시오. 그래프를 런타임이 아니라 빌드 시점에
검사하고 싶다면 [GUIDE_CODEGEN.ko.md](GUIDE_CODEGEN.ko.md)를 읽으십시오. 두 모드는 하나의 그래프 안에서
함께 조합되므로, 한번 고르면 되돌릴 수 없는 결정이 아닙니다.

---

## 목차

**첫 앱이라면 1–5절이면 충분합니다.** 설치, 등록, 앱 시작, 위젯에서 읽기까지입니다. 나머지는 필요할 때
읽으면 됩니다. 각 절은 질문 하나에 답합니다. 제너레이터를 쓰는 가장 작은 완성 앱은
[`examples/hello`](examples/hello)입니다.

**그다음 순서:** 나만의 스코프(갤러리의 「세션 스코프」 항목과 [6절](#6-앱보다-먼저-끝나는-스코프)), 그다음
의존성을 바꿔 끼우는 테스트([`examples/testing_patterns`](examples/testing_patterns)와 [13절](#13-테스트))입니다.
Flutter 없이: [`examples/manual_mode`](examples/manual_mode)와 [`examples/teardown`](examples/teardown),
둘 다 순수 Dart입니다.

1. [설치](#1-설치)
2. [첫 그래프](#2-첫-그래프)
3. [등록과 읽기](#3-등록과-읽기)
4. [Flutter 앱 시작하기](#4-flutter-앱-시작하기)
5. [위젯에서 그래프 읽기](#5-위젯에서-그래프-읽기)
6. [앱보다 먼저 끝나는 스코프](#6-앱보다-먼저-끝나는-스코프)
7. [등록한 것 닫기](#7-등록한-것-닫기)
8. [앱이 시작되기 전에 끝나야 하는 작업](#8-앱이-시작되기-전에-끝나야-하는-작업)
9. [호출하는 쪽에서 오는 값](#9-호출하는-쪽에서-오는-값)
10. [선택적 의존성](#10-선택적-의존성)
11. [그래프 하나, 여러 빌드](#11-그래프-하나-여러-빌드)
12. [그래프 관찰하기](#12-그래프-관찰하기)
13. [테스트](#13-테스트)
14. [미리 알아 둘 만한 실수](#14-미리-알아-둘-만한-실수)
15. [제너레이터를 추가할 시점](#15-제너레이터를-추가할-시점)

---

## 1. 설치

순수 Dart 프로그램(CLI, 서버, 위젯이 없는 패키지)에는 의존성 하나면 됩니다:

```yaml
environment:
  sdk: ^3.10.0

dependencies:
  cobalt: ^1.0.0
```

Flutter 앱은 바인딩을 추가합니다. 바인딩이 런타임 전체를 다시 export하므로 둘을 함께 import할 일은 없습니다:

```yaml
environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  cobalt: ^1.0.0
  cobalt_flutter: ^1.0.0

dev_dependencies:
  cobalt_test: ^1.0.0
  cobalt_test_flutter: ^1.0.0
```

**여기에는 막다른 길이 없습니다.** 하한은 Dart `^3.10.0` / Flutter `>=3.38.0`으로,
[GUIDE_CODEGEN.ko.md](GUIDE_CODEGEN.ko.md)가 요구하는 것과 같습니다. 그래서 나중에 제너레이터를 추가하는
것은 업그레이드가 아니라 선택입니다. 두 모드가 어떻게 조합되는지는 [§15](#15-제너레이터를-추가할-시점)를 참고하십시오.

선택 사항이며 원할 때만 추가합니다: 내비게이션 플로우마다 스코프를 두는 `cobalt_go_router`, 스코프가 bloc을
닫을 수 있게 하는 `cobalt_bloc`, 앱이 실행되는 동안 그래프를 보여 주는 `cobalt_inspector`, 그리고 관측성을
위한 `cobalt_talker` / `cobalt_logging` / `cobalt_logger` 중 하나입니다.

여기서는 `cobalt_generator`, `build_runner`, `cobalt_lint`가 필요 없습니다. 그것들은 다른 모드의 것입니다.

---

## 2. 첫 그래프

세 가지로 이루어집니다. 클래스, 클래스마다 하나씩인 팩토리, 그리고 그것들을 등록하는 빌더입니다.

```dart
import 'package:cobalt/cobalt.dart';

class Clock {
  DateTime now() => DateTime.now();
}

class EventLog implements Disposable {
  final entries = <String>[];

  void add(String entry) => entries.add(entry);

  @override
  void dispose() => entries.clear();
}
```

**팩토리**는 클로저가 아니라 객체입니다. 그래서 `const`일 수 있고, 캡처된 상태를 갖지 않으며, 그래프가
시작될 때마다 공유될 수 있습니다. 클로저는 작성한 위치에서 보이던 것을 무엇이든 캡처하는데, 두 번째 시작이
첫 번째 시작의 객체를 재사용하는 버그가 바로 여기서 생깁니다.

```dart
class ClockFactory implements CobaltFactory<Clock> {
  const ClockFactory();

  @override
  Clock create(CobaltResolver resolver) => Clock();
}

class EventLogFactory implements CobaltFactory<EventLog> {
  const EventLogFactory();

  @override
  EventLog create(CobaltResolver resolver) => EventLog();
}
```

의존성은 `create` 안에서, 넘겨받은 리졸버로 해석합니다:

```dart
class ReportFactory implements CobaltFactory<Report> {
  const ReportFactory();

  @override
  Report create(CobaltResolver resolver) =>
      Report(resolver.get<Clock>(), resolver.get<EventLog>());
}
```

**스코프 빌더**는 스코프가 무엇을 보유하는지 기술합니다. 등록만 하고 해석은 하지 않습니다. `build` 도중에
해석하면 아직 기술되고 있는 그래프를 읽게 되기 때문입니다.

```dart
class AppScope implements CobaltScopeBuilder {
  const AppScope();

  @override
  void build(CobaltScope scope) {
    scope
      ..registerLazySingleton<Clock>(const ClockFactory())
      ..registerLazySingleton<EventLog>(const EventLogFactory())
      ..registerLazySingleton<Report>(const ReportFactory());
  }
}

Future<void> main() async {
  final app = await CobaltApplication.start(root: const AppScope(), rootName: 'app');

  app.get<EventLog>().add('started at ${app.get<Clock>().now()}');

  await app.dispose();
}
```

등록 순서는 상관없습니다. `Report`를 `Clock`보다 먼저 등록해도 됩니다. `build` 중에는 아무것도 빌드되지
않으며, 무언가가 해석될 무렵에는 모든 등록이 이미 존재합니다.

전역 컨테이너는 없습니다. `CobaltApplication.start`가 루트를 건네주고 암묵적으로 주어지는 것은 없으므로,
한 프로세스 안의 두 그래프는 서로 무관하고 테스트는 병렬로 실행될 수 있습니다.

`examples/manual_mode`가 이 예제를 완성해 실행할 수 있게 만든 것입니다:

```bash
cd examples/manual_mode && dart run
```

---

## 3. 등록과 읽기

### 등록하는 아홉 가지 방법

| 호출 | 빌드 시점 | 스코프가 보유 |
|---|---|---|
| `registerSingleton<T>(value)` | 이미 빌드됨, 여러분이 | 예 |
| `registerEagerSingleton<T>(factory)` | 지금, 스코프가 | 예 |
| `registerLazySingleton<T>(factory)` | 첫 해석 시 | 예 |
| `registerAsyncSingleton<T>(factory)` | `init()` 중, 의존성 순서대로 | 예 |
| `registerLazyAsyncSingleton<T>(factory)` | 첫 `getAsync` 시 | 예 |
| `registerFactory<T>(factory)` | 해석할 때마다 | 아니요 |
| `registerAsyncFactory<T>(factory)` | `getAsync`할 때마다 | 아니요 |
| `registerParamFactory<T, P>(factory)` | 해석할 때마다, 인자로부터 | 아니요 |
| `registerAsyncParamFactory<T, P>(factory)` | `getAsyncWithParam`할 때마다, 인자로부터 | 아니요 |

구분은 오직 "보유" 여부이며, 이것이 해제를 결정합니다. 스코프는 자신이 보유한 것을 해제하고, 트랜지언트는
누구도 해제할 책임이 없습니다. [§7](#7-등록한-것-닫기)을 참고하십시오.

`name` 한정자를 쓰면 같은 타입을 두 번째로 등록할 수 있습니다. 키가 타입과 이름 *둘 다*이기 때문입니다:

```dart
scope
  ..registerLazySingleton<Logger>(const AppLoggerFactory())
  ..registerLazySingleton<Logger>(const AuditLoggerFactory(), name: 'audit');
```

한 스코프에 같은 키를 두 번 등록하면 예외가 발생합니다. 그렇게 하지 않고 등록을 대체하는 방법은 두 가지입니다.
키를 소유한 스코프에 넘기는 재정의, 그리고 그 아래에서 해석되는 것에 대해 등록을 섀도잉하는 자식 스코프의
등록입니다. [§13](#13-테스트)을 참고하십시오.

### 읽는 여섯 가지 방법

```dart
scope.get<Repository>();                       // 아무것도 등록되어 있지 않으면 예외를 던집니다
scope.getOrNull<Telemetry>();                  // 대신 null을 돌려줍니다, §10 참고
scope.get<Logger>(name: 'audit');              // 이름 지정 등록
scope.getAll<NoteFormatter>();                 // 해당 타입의 모든 등록, 가장 가까운 스코프부터
scope.getWithParam<Counter, String>('alice');  // 파라미터가 있는 등록
await scope.getAsync<SearchEngine>();          // 지연 비동기 등록을 먼저 빌드합니다, §8 참고
```

`isRegistered<T>()`는 아무것도 빌드하지 않고 답합니다.

해석은 위로 올라갑니다. 이 스코프, 그다음 부모, 그렇게 루트까지 갑니다. `getAll`은 체인 전체에서 가장
가까운 것부터 모으며, 섀도잉된 키는 그 키를 가진 가장 가까운 스코프에서 한 번만 가져옵니다.

### 스코프가 보유한 것 살펴보기

진단용이며, 어느 것도 무언가를 빌드하지 않습니다:

```dart
scope.keys;                  // 이 스코프 자신의 등록, 등록 순서대로
scope.visibleKeys;           // 위의 것과 상속된 것, 각각을 소유한 스코프에 매핑됨
scope.root;                  // 트리의 꼭대기
scope.describeTree();        // 텍스트로 표현한 트리

final info = scope.registrationOf(const CobaltKey(SearchEngine));
info?.kind;                  // lazyAsyncSingleton, transient 등
info?.implementation;        // 빌드하는 클래스, 팩토리가 알려 줄 때
info?.decorators;            // 감싸는 데코레이터, 가장 안쪽부터
info?.isOverridden;          // 재정의가 제공하는지 여부
```

`visibleKeys`가 집합이 아니라 맵인 데에는 일찍 익혀 둘 만한 이유가 있습니다. 팩토리는 여러분이 요청한
스코프가 아니라 *자기* 등록을 소유한 스코프에서 실행됩니다. 어느 스코프가 키를 소유하는지 알아야 재정의가
보일지 알 수 있습니다. [§13](#13-테스트)을 참고하십시오.

`registrationOf`는 `get`처럼 조상까지 거슬러 올라가 답하며, 키를 등록한 곳이 없으면 null을 반환합니다.
`hooks`와 `adoptedTypes`는 스코프에 추가된 훅과 `adopt`에 넘긴 것을 나열하고,
`CobaltScope.previewRegistrations(builder)`는 아무것도 빌드하지 않고 빌더가 무엇을 등록하는지 나열합니다.
`describeTree()`는 읽기 위한 것이지 파싱하기 위한 것이 아닙니다. 그 텍스트의 형태는 어느 릴리스에서든 바뀔 수
있습니다.

이것들은 읽기 전용 `debug…` 멤버(`debugDescribeTree`, `debugKindOf`, `debugDecoratorsOf` 등)를
대체합니다. 그 멤버들은 여전히 동작하지만 deprecated 상태이며 2.0에서 제거됩니다. `@experimental`로 남는 것은
`debugResolve…` 멤버뿐입니다. semver 밖에 있으므로 마이너 릴리스에서 바뀔 수 있고, 새로운 analyzer는 다른
패키지에서의 사용을 `experimental_member_use`로 표시합니다. 테스트에서는 괜찮지만, 그 위에 무언가를 쌓아 올릴
것은 아닙니다.

---

### 등록 감싸기

데코레이터는 등록이 내주는 객체를 그 클래스를 건드리지 않고 감쌉니다. 로그, 재시도, 캐시, 직접 소유하지
않은 클라이언트를 둘러싼 메트릭 등입니다:

```dart
class LoggingApi implements CobaltDecorator<ApiClient> {
  const LoggingApi();

  @override
  ApiClient decorate(ApiClient inner, CobaltResolver resolver) =>
      LoggedApiClient(inner, resolver.get<Logger>());
}

scope
  ..registerLazySingleton<ApiClient>(const ApiClientFactory())
  ..decorate<ApiClient>(const LoggingApi());
```

데코레이터는 추가된 순서대로 적용되며 처음 것이 가장 안쪽입니다. 데코레이터는 등록을 소유한 스코프의
리졸버를 봅니다. 보유되는 등록에는 처음 해석될 때 한 번 데코레이터가 적용되고 모두가 그 결과를 공유합니다.
트랜지언트나 파라미터가 있는 등록에는 빌드될 때마다 적용됩니다. `build()` 안에서 `decorate`가 등록보다
앞에 오든 뒤에 오든 상관없으며, 재정의에도 그것이 대체한 등록과 똑같이 데코레이터가 적용됩니다.

안쪽 인스턴스는 계속 스코프가 소유하고 한 번 닫습니다. 데코레이터는 닫을 것을 아무것도 보유하지 않습니다.
세 가지 실수는 거부됩니다. 이미 해석된 키에 데코레이터를 적용하는 것(그 키를 받아 간 쪽은 데코레이터가
적용되지 않은 인스턴스를 계속 쥐게 됩니다), 스코프가 등록하지 않은 키에 적용하는 것(`runBuilder`가 그 키를
소유한 조상을 알려 줍니다), 그리고 자기 키를 해석하는 데코레이터로, 이는 `CobaltCycleError`입니다.

한 타입의 모든 등록, 즉 이름 없는 `ApiClient`와 이름 있는 각각을 감싸려면
`decorateAll`을 쓰십시오:

```dart
scope.decorateAll<ApiClient>(const LoggingApi());
```

이것은 자신보다 앞에 추가된 그 타입의 등록과 뒤에 추가된 등록을 모두 감싸며, `decorate`와 하나의 순서를
공유합니다. 키를 감싸는 것은 그 키에 대해 추가되었든 그 타입에 대해 추가되었든 추가된 순서대로 적용됩니다.
거부되는 경우도 같은 두 가지입니다. 그 타입의 키가 이미 해석된 경우, 또는 스코프가 그 타입의 키를 하나도
등록하지 않은 경우입니다.


데코레이터는 등록이 약속한 것을 돌려줘야 하므로 "`Loggable`인 모든 것"에는 닿을 수 없습니다. `Loggable`을
감싼 래퍼는 `Api` 등록이 호출하는 쪽에 약속한 `Api`가 아니기 때문입니다. 이를 위해 훅이 있습니다. 훅은
스코프(또는 그 아래의 어떤 스코프든)가 빌드하는 자기 타입의 모든 인스턴스를, 어느 등록이 빌드했든 보고,
바꾸지 않은 채 그대로 넘깁니다:

```dart
final class JoinRegistry extends CobaltHook<Loggable> {
  const JoinRegistry();

  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) =>
      resolver.get<LogRegistry>().add(instance);
}

scope.hookAll<Loggable>(const JoinRegistry());
```

훅은 인스턴스가 빌드되어 넘겨진 직후, 누군가 받기 전에, 팩토리가 만든 그대로의 것(어떤 데코레이터도 감싸기
전)에 대해 실행되며, 즉시 생성과 비동기를 포함한 모든 종류의 등록에서 실행됩니다. `registerSingleton`으로
넘긴 값은 여기서 빌드된 것이 아니므로 훅을 거치지 않습니다. 조상의 훅이 그 스코프 자신의 훅보다 먼저
실행되고, 각 스코프 안에서는 추가된 순서대로 실행되며, `resolver`는 인스턴스를 빌드한 스코프입니다.
예외를 던지는 훅은, 예외를 던지는 `@injected` 필드와 마찬가지로 요청한 호출을 실패시킵니다. 스코프나 그 아래
스코프가 이미 무언가를 빌드한 뒤에 추가한 훅은 `CobaltHookError`로 거부됩니다. 그것들을 놓쳤을 것이기
때문입니다. 따라서 훅은 스코프를 구성하는 곳에서, 어떤 즉시 생성 등록보다도 앞에 추가하십시오.

훅은 메서드 두 개를 가진 base 클래스이며, 둘 다 오버라이드하기 전에는 비어 있습니다. 두 번째인 `onReleased`는
첫 번째를 되돌립니다. 스코프가 해제될 때 스코프가 보유했던 모든 인스턴스가 거쳐 갔던 훅을 가장 안쪽부터,
닫히기 전에 다시 지나갑니다. 그래서 레지스트리에 합류한 것은 아직 동작하는 동안 거기서 빠져나갈 수 있습니다.
트랜지언트는 돌아오지 않습니다. 그것은 스코프가 아니라 호출한 쪽의 것이었기 때문입니다.

## 4. Flutter 앱 시작하기

`CobaltAppScope`는 루트를 소유합니다. 그래프를 빌드하고, 위젯 트리에 게시하고, 언마운트될 때 해제하며,
실패한 시작을 첫 프레임 전에 죽는 앱이 아니라 재시도할 수 있는 화면으로
바꿉니다.

`MaterialApp` 위가 아니라 `MaterialApp.builder`에 두십시오. 그곳은 `Theme`, `Directionality`,
`Localizations` 아래이므로, `loading`과 `errorBuilder`가 두 번째 `MaterialApp`이 아니라
평범한 화면이 됩니다:

```dart
void main() => runApp(
  MaterialApp(
    theme: appTheme,
    builder: CobaltAppScope.builder(
      root: const AppScope(),
      bootstrap: () => [const BindPlatform()],
      rootName: 'app',
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: (context, error, retry) => StartupFailed(error: error, retry: retry),
    ),
    home: const HomeScreen(),
  ),
);
```

`bootstrap`이 리스트가 아니라 함수인 것은 의도적입니다. 단계는 리소스를 보유하며, 재시작하면 새 단계를
받아야 합니다. 저장된 리스트라면 두 번째 시작에 같은 객체를 조용히 넘겨줄 것입니다.

`CobaltAppScope.of(context).restart()`는 그래프를 다시 빌드합니다. 실패한 시작을 재시도하는 것도 같은 호출입니다.

앱에 이미 `builder`가 있다면, 프레임워크가 둘을 합쳐 주기를 기대하지 말고 직접
조합하십시오:

```dart
builder: (context, child) => CobaltAppScope(
  root: const AppScope(),
  child: myWrapper(child!),
),
```

---

**`build()` 안의 순서는 즉시 생성 등록에는 중요하고 지연 등록에는 중요하지 않습니다.**
`registerLazySingleton`은 나중에 빌드하겠다는 약속이므로 위나 아래에 무엇이 등록되든 상관하지 않습니다.
`registerSingleton`은 *지금* 빌드하므로, 그것이 해석하는 것은 이미 등록되어 있어야 합니다. 생성된 빌더 위에
직접 작성한 빌더를 조합할 때 이 문제가 드러납니다. 즉시 생성 등록은 컨테이너 뒤에 두거나, 지연 등록으로
바꾸십시오.

**그래프를 바꾸는 핫 리로드는 그래프를 다시 시작합니다.** 리로드는 코드를 패치하지만 `build()`를 다시
실행하지 않으므로, 그렇지 않다면 방금 추가한 등록은 핫 리스타트를 기다려야 합니다. 리로드할 때마다
`CobaltAppScope`는 아무것도 빌드하지 않고 `root`를 한 번 더 실행해 그 등록을 살아 있는 루트의 등록과
비교하며, 키가 추가되거나 제거되거나 수명이 바뀐 경우에만 `restart()`를 호출하고 무엇이 바뀌었는지
출력합니다. 위젯이나 팩토리 본문만 건드린 리로드는 그래프와 화면 상태를 그대로 둡니다.
`restartOnGraphChange: false`로 끌 수 있습니다. `CobaltAppScope.start`에는 비교할 빌더가 없으며,
`bootstrap` 리스트는 비교하지 않습니다.

## 5. 위젯에서 그래프 읽기

```dart
final repository = context.cobalt<Repository>();
final formatters = context.cobaltAll<NoteFormatter>();
final counter = context.cobaltWithParam<Counter, String>('alice');
final scope = context.cobaltScope;
```

각각은 위젯 위의 **가장 가까운** 스코프에서 해석하고 거기서부터 위로 올라가므로, 플로우나 세션 스코프의
등록은 그 안의 모든 것에 대해 루트의 등록을 섀도잉합니다.

문제를 겪기 전에 알아 둘 것이 하나 있습니다. `Navigator.push`는 새 라우트를 push한 위젯이 아니라
내비게이터의 context에서 빌드합니다. 제자리에 마운트되었을 때는 잘 해석되던 화면도, 읽던 프로바이더가
push하는 화면 *안에* 있다면 같은 위젯을 push했을 때 `CobaltNoScopeError`를 던집니다. 그런 경우에는 스코프를
명시적으로 넘기거나, 프로바이더 아래에서 push하십시오.

---

## 6. 앱보다 먼저 끝나는 스코프

프레임워크가 존재하는 이유가 바로 이것입니다. 스코프는 트리의 노드이고, 자신이 빌드한 것을 소유하며,
스코프를 해제하면 그 아래의 모든 것이 함께 해제됩니다.

### 세션

```dart
class SessionManager {
  SessionManager(this._root);

  final CobaltScope _root;
  CobaltScope? _session;

  Future<void> signIn(User user) async {
    _session = _root.push('session:${user.id}')
      ..registerLazySingleton<Draft>(const DraftFactory())
      ..registerLazySingleton<SyncQueue>(const SyncQueueFactory());
    await _session!.init();
  }

  Future<void> signOut() async {
    await _session?.dispose();
    _session = null;
  }
}
```

로그아웃은 `await scope.dispose()`입니다. 세션 스트림을 구독하는 리포지토리도 없고, 원하지 않던 `reset()`
메서드가 생겨나는 도메인 인터페이스도 없습니다.

`push`는 자식을 즉시 반환하고, `init()`은 그 비동기 등록을 실행합니다. 비동기 등록이 없더라도 `init()`을
호출하십시오. 비용이 적고 멱등이며, 나중에 비동기 등록을 추가해도 호출하는 코드를 바꿀 필요가
없습니다.

### 화면

```dart
CobaltScopeWidget(
  name: 'editor',
  builder: const EditorScope(),
  child: const EditorBody(),
)
```

위젯이 마운트될 때 생성되고, 언마운트될 때 해제됩니다. 스코프는 `init()`이 완료된 뒤에야 게시되므로,
완전히 동기적인 그래프도 `loading` 프레임을 한 번 렌더링한다는 점에 유의하십시오.

### 내비게이션 플로우

`cobalt_go_router`를 쓰면 수명은 잊지 않고 배치해야 하는 위젯이 아니라 플로우가 됩니다:

```dart
class OrderFlowRoute extends CobaltShellRoute {
  OrderFlowRoute()
    : super(
        name: 'order',
        identity: _orderId,
        scope: (state) => OrderFlowScope(_orderId(state)),
        routes: [
          GoRoute(
            path: '/orders/:orderId/summary',
            builder: (_, state) => OrderSummaryScreen(orderId: _orderId(state)),
          ),
          GoRoute(
            path: '/orders/:orderId/payment',
            builder: (_, state) => OrderPaymentScreen(orderId: _orderId(state)),
          ),
        ],
      );

  static String _orderId(GoRouterState state) => state.pathParameters['orderId']!;
}

class OrderFlowScope implements CobaltScopeBuilder {
  const OrderFlowScope(this.orderId);

  final String orderId;

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<OrderDraft>(OrderDraftFactory(orderId));
}
```

여기서 `OrderDraftFactory`는 `const`가 아니라는 점에 유의하십시오. 주문 id를 가지고 있기 때문입니다.
설정값을 받는 팩토리는 괜찮습니다. 해서는 안 되는 것은 주변 그래프를 캡처하는 것입니다.

`summary`와 `payment` 사이를 이동하는 동안에는 스코프 하나가 유지됩니다. 플로우를 떠나면 해제됩니다.
`identity`는 라우터가 답할 수 없는 단 하나의 질문, 즉 `/orders/1`과 `/orders/2`가 같은 플로우인지에 답합니다.

라우트 테이블은 라우터와 함께 **한 번만** 빌드하십시오. go_router 입장에서 새 `CobaltShellRoute` 인스턴스는
다른 플로우이므로, 매 프레임 리스트를 다시 만들면 매 프레임 스코프도 다시
빌드됩니다.

탭도 `CobaltStatefulShellRoute`와 `CobaltStatefulShellBranch`로 같은 방식으로 동작하는데, 분명히 말해 둘
동작이 하나 있습니다. 브랜치는 **보이는** 상태가 아니라 **살아 있는** 상태로 유지됩니다. go_router는
브랜치 내비게이터를 화면 밖에서도 보존하므로, 탭의 스코프는 다른 탭으로 전환할 때가 아니라 셸이 닫힐 때까지
살아 있습니다.

---

## 7. 등록한 것 닫기

스코프는 보유한 것을 **생성** 순서의 역순으로 해제합니다. 선언 순서가 아닙니다. 직접 작성한 컨테이너의 버그가
바로 여기에 있습니다. 먼저 선언되었지만 마지막에 생성된 컴포넌트가, 아직 무언가가 그것에 의존하는 동안
먼저 파괴됩니다.

Dart에는 구조적 타이핑이 없으므로, 이름이 맞는 `dispose()` 메서드만으로는 충분하지 않습니다. 어느
인터페이스인지 명시하십시오:

```dart
class Cache implements Disposable {
  @override
  void dispose() { ... }
}

class Database implements AsyncDisposable {
  @override
  Future<void> dispose() async { ... }
}
```

바꿀 수 없는 타입(SDK의 타입, 다른 패키지의 타입, base 클래스 뒤에 있는 타입)이라면 등록에서 해제 방법을
지정하십시오:

```dart
scope.registerLazySingleton<http.Client>(
  const ClientFactory(),
  dispose: (client) => client.close(),
);

scope.registerAsyncSingleton<Isar>(
  const IsarFactory(),
  dispose: (isar) => isar.close(),
);
```

`dispose:`는 스코프가 보유하는 등록에만 있습니다. `registerFactory`와 `registerParamFactory`는 이를 받지
않습니다. 트랜지언트는 스코프가 닫을 대상이 아니기 때문이며, 이 경우는 런타임에 검사되는 것이 아니라 아예
표현할 수 없습니다. 트랜지언트가 무언가를 소유한다면, 그것을 사용하는 쪽이 그것도 소유합니다.

### 닫을 수 있어 보이지만 그렇지 않은 Flutter 타입

`ChangeNotifier.dispose`는 `Disposable.dispose`와 정확히 일치하지만, 그래도 스코프에는 보이지 않습니다.
Dart는 인터페이스를 형태가 아니라 이름으로 맞추기 때문입니다. 명시하십시오:

```dart
class Filters extends ChangeNotifier implements Disposable {}
```

bloc에는 `cobalt_bloc`이 한 줄로 해결해 줍니다:

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);
}
```

또는 믹스인을 쓸 수 없는 곳이라면 등록에서 `dispose: closeBloc`을 지정합니다.

그리고 위젯 트리에는 `BlocProvider(create:)`가 아니라 반드시 `BlocProvider.value`로 넘기십시오. 전자는
언마운트될 때 넘겨받은 것을 닫아 버리지만, 스코프는 여전히 그것을 보유하고 있어 다음 해석 때 죽은 객체를
내주게 됩니다.

### 해제가 잘못되었을 때

해제는 설계상 최선을 다하는(best-effort) 방식입니다. 예외를 던진 단계는 기록되고 나머지는 계속 실행되며,
트리 전체가 기한 하나를 공유하고, 스코프는 언제나 `disposed`에 도달합니다. 끝나지 않은 것은 첫 번째 실패가
나머지 아홉을 가리는 대신 `CobaltDisposeError`(`failures`, `timeouts`, `hasTimeout`)에
나열됩니다.

`adopt`는 객체를 의존성으로 만들지 않고 스코프의 수명에 묶습니다. 아무것도 해석하지 않는 구독이나 타이머에
유용합니다:

```dart
scope.adopt(subscription, dispose: (it) => it.cancel());
```

`examples/teardown`은 이 모든 것을 콘솔 프로그램으로 실행하며 단계마다 출력합니다. 생성의 역순, `adopt`,
하나의 마감 시간 아래에서 실패하는 서비스와 멈춘 서비스, 그리고 그 결과인 `CobaltDisposeError`까지 보여 줍니다:

```bash
cd examples/teardown && dart run bin/main.dart
```

---

## 8. 앱이 시작되기 전에 끝나야 하는 작업

서로 다른 질문에 답하는 두 단계가 있습니다.

**0단계: 부트스트랩 단계.** 컨테이너가 생기기 전입니다. 플랫폼 바인딩, 원격 설정 등 그래프 자체에 필요한
모든 것입니다. 단계는 나열한 순서대로 엄격하게 실행되며, 아무것도 주입받을 수 없습니다. 아직 주입해 줄 곳이
없기 때문입니다.

```dart
class BindPlatform implements CobaltBootstrapStep {
  const BindPlatform();

  @override
  String get name => 'bind-platform';

  @override
  Future<void> run() async => WidgetsFlutterBinding.ensureInitialized();
}

final app = await CobaltApplication.start(
  root: const AppScope(),
  bootstrap: const [BindPlatform(), LoadRemoteConfig()],
  rootName: 'app',
);
```

실행이 끝나면 루트 스코프가 단계들을 `adopt`하므로, 무언가를 연 단계는 해제 시 그것이 닫힙니다. 그 위에
빌드된 모든 것이 닫힌 뒤 마지막으로 닫힙니다. 단계가 실패하면 이미 실행된 단계들은 오류가 다시 던져지기
전에 역순으로 해제됩니다. 넘겨줄 스코프가 아직 없기 때문입니다.

**1단계: 비동기 싱글턴.** 컨테이너 안에서, 의존성 순서대로 빌드됩니다:

```dart
class DatabaseFactory implements CobaltAsyncFactory<Database> {
  const DatabaseFactory();

  @override
  Future<Database> create(CobaltResolver resolver) async {
    final database = Database(resolver.get<Config>());
    await database.open();
    return database;
  }
}

scope
  ..registerAsyncSingleton<Database>(const DatabaseFactory())
  ..registerAsyncSingleton<SearchIndex>(
    const SearchIndexFactory(),
    dependsOn: {CobaltKey(Database)},
  );
```

`dependsOn`은 주입이 아니라 순서를 정하는 간선입니다. `Database`는 여전히 `SearchIndexFactory.create`
안에서 해석합니다. 같은 계층의 독립된 초기화는 `Future.wait`로 함께 실행되며, 실제로 의존하는 것만
기다립니다. 순환이 있으면 멈춰 버리는 대신 그 경로를 지목하는 `CobaltCycleError`를
던집니다.

등록되어 있지만 비동기가 **아닌** 키를 지정하면 아무 일도 하지 않는 것이 아니라 오류입니다. 기다릴 빌드가
없기 때문입니다. **조상** 스코프에서 비동기인 키를 지정하는 것은 허용되며 무시됩니다. 조상은 이 스코프가
생기기 전에 자신의 1단계를 이미 실행했습니다.

`CobaltApplication.start`는 두 단계가 모두 끝나야 반환하므로, 호출할 `allReady()`도, 따져 봐야 할
"등록되었지만 준비되지 않은" 상태도 없습니다.

비동기 등록은 `init()`이 실행되기 전에 존재해야 합니다. `init()`은 시작할 때 찾은 등록을 가져가 한 번만
실행되므로, 이미 활성화된 스코프에 비동기 등록을 더 추가하면 조용히 영영 빌드되지 않는 대신 오류가 됩니다.
대신 자식 스코프를 push하고 그것을 초기화하십시오.

응답하지 않는 소켓을 기다리는 초기화는 앱을 스플래시 화면에 영원히 붙잡아 둡니다. 1단계에 시간 예산을 주면
대신 실패하며, 무엇을 기다리고 있었는지 알려 줍니다:

```dart
final app = await CobaltApplication.start(
  root: const AppScope(),
  initTimeout: const Duration(seconds: 15),
);
```

시간이 지나면 `init`은 아직 빌드되지 않은 모든 비동기 싱글턴을 나열하는 `CobaltInitTimeoutError`를 던지고,
루트는 시작에 실패한 다른 루트와 마찬가지로 해제됩니다. future는 취소할 수 없으므로 진행 중인 빌드는 끝까지
실행됩니다. 각 빌드는 끝나는 대로 닫히며, 다음 계층은 시작되지 않습니다. 직접 초기화하는 스코프에는
`scope.init(timeout:)`이 같은 일을 하고, `CobaltAppScope(initTimeout:)`는 이를 `errorBuilder` 화면으로
바꿉니다. 타임아웃이 없으면 init은 이전처럼 필요한 만큼 기다립니다.

### 처음 요청될 때 빌드

1단계는 시작할 때 모든 것을 빌드합니다. 앱과 수명이 같지만 필요로 하는 화면은 적은, 비용이 큰 객체라면
이는 잘못된 선택입니다. 대신 지연 등록하면 첫 `getAsync`까지 아무것도
빌드되지 않습니다:

```dart
scope.registerLazyAsyncSingleton<SearchEngine>(const SearchEngineFactory());

final engine = await scope.getAsync<SearchEngine>();
```

다른 싱글턴과 마찬가지로 스코프가 보유하며, *생성된* 순서에 따라 스코프와 함께 해제됩니다. 동시에 들어온
호출은 빌드 하나를 공유합니다. 실패한 빌드는 기억되지 않습니다. 기다리던 모두가 오류를 받고, 다음 호출이
다시 시도합니다. 놓칠 단계가 없으므로 `init()` 이후에 등록해도
됩니다.

빌드된 뒤에는 동기로 읽어도 동작합니다. 그 전에는 `get`이 `getAsync`를 안내하는 `CobaltLazyAsyncError`를
던지며, `getAll`도 마찬가지입니다. `getAll`에는 짝이 되는 `getAllAsync`가 있습니다. 지연 팩토리는 리졸버를
통해 다른 지연 등록을 기다릴 수 있습니다. 자기 키로 되돌아오는 체인은 멈춰 버리는 것이 아니라 경로가 담긴
`CobaltCycleError`가 됩니다. 비동기 싱글턴은 `dependsOn`에 지연 등록을 지정할 수 없습니다. `init()`이
기다릴 것이 없기 때문입니다.

`dispose`는 진행 중인 빌드를 기다렸다가 그 결과를 해제합니다. 기한을 넘겨서도 실행 중인 빌드는 다른 초과와
마찬가지로 포기되며, 나중에 끝나면 그 결과는 즉시 닫힙니다.

위젯에서는 `CobaltAsyncBuilder`가 첫 화면이 빌드하는 동안 `loading`을 보여 주고, 그 이후의 모든 화면에서는
바로 렌더링합니다:

```dart
CobaltAsyncBuilder<SearchEngine>(
  loading: const Center(child: CircularProgressIndicator()),
  errorBuilder: (context, error, retry) => RetryView(onRetry: retry),
  builder: (context, engine) => SearchScreen(engine: engine),
)
```


화면이 열리기 전에 준비해 두려면 워밍업하십시오. `warmUp`은 리스트의 모든 빌드를 시작 경로 밖에서 한꺼번에
시작합니다. 각각은 `getAsync`가 시작했을 바로 그 빌드이므로, 그사이에 요청한 화면은 두 번째 빌드를 시작하지
않고 그것을 기다립니다:

```dart
unawaited(scope.warmUp(const [CobaltKey(SearchEngine)]));
```

무엇이든 빌드되기 전에 모든 키를 검사하며, 실패한 빌드가 나머지를 멈추지 않습니다. 실패는
`CobaltWarmUpError` 하나로 함께 전달됩니다. Flutter에서는 `CobaltAppScope(warmUp: [...])`가 그래프가
올라오자마자, `loading`을 붙잡아 두지 않고 앱이 표시되는 동안 뒤에서 이를 수행하며, 실패는
`FlutterError.reportError`로 보고합니다.


### 호출할 때마다 새로 빌드

호출하는 쪽마다 자기 인스턴스가 필요하고 그 빌드가 무언가를 기다려야 한다면(자기 연결을 여는 쿼리, 요청 시
조립되는 리포트 등) 비동기 트랜지언트를 등록하고
`getAsync`로 읽으십시오:

```dart
class ReportFactory implements CobaltAsyncFactory<Report> {
  const ReportFactory();

  @override
  Future<Report> create(CobaltResolver resolver) =>
      resolver.get<ReportService>().assemble();
}

scope.registerAsyncFactory<Report>(const ReportFactory());

final report = await scope.getAsync<Report>();
```

호출할 때마다 스코프가 보유하지 않는 새 인스턴스를 빌드합니다. 호출한 쪽이 그것을 소유하고 닫습니다. 동시에
들어온 호출도 빌드를 공유하지 않습니다. `init()`이 빌드하는 일은 없으므로 나중에 등록해도 되며, 비동기
싱글턴은 `dependsOn`에 이를 지정할 수 없습니다. 그 팩토리는 `getAsync`로 지연 등록을 기다릴 수 있으며, 자신의
await를 거쳐 지금 빌드 중인 키를 요청하는 빌드는 멈춰 버리는 대신 `CobaltCycleError`가 됩니다. 동기로
읽으면(`get`, `getOrNull`, `getAll`) `getAsync`를 안내하는 `CobaltAsyncTransientError`를 던집니다. 테스트에서는
`CobaltOverride.transient`가 이를 동기 대역으로 교체합니다.

위젯에서는 `context.cobaltAsync`를 `initState`나 이벤트에서 한 번만 호출하고 그 future를 보관하십시오.
호출할 때마다 또 하나를 빌드하기 때문입니다.

---

## 9. 호출하는 쪽에서 오는 값

객체의 절반은 그래프에서, 나머지 절반은 그것을 빌드하는 쪽에서 옵니다:

```dart
class CounterFactory implements CobaltParamFactory<Counter, String> {
  const CounterFactory();

  @override
  Counter create(CobaltResolver resolver, String sessionId) =>
      Counter(resolver.get<CounterStorage>(), sessionId);
}

scope.registerParamFactory<Counter, String>(const CounterFactory());

final counter = scope.getWithParam<Counter, String>('alice');
```

파라미터는 하나입니다. 둘 이상이라면 레코드로 묶으십시오. 호출하는 코드가 여전히 읽기 쉽도록 이름 있는
레코드로 묶습니다:

```dart
typedef EditorArgs = ({int id, String title, bool draft});

class EditorFactory implements CobaltParamFactory<Editor, EditorArgs> {
  const EditorFactory();

  @override
  Editor create(CobaltResolver resolver, EditorArgs args) =>
      Editor(resolver.get<Notes>(), id: args.id, title: args.title, draft: args.draft);
}

scope.getWithParam<Editor, EditorArgs>((id: 7, title: 'draft', draft: true));
```

파라미터 타입은 팩토리 안이 아니라 호출 시점에 검사합니다. 잘못된 타입을 넘기면 키, 기대한 타입, 실제로
들어온 것을 알려 주는 `CobaltParamTypeError`를 던집니다. 검사 대상이 타입 리터럴이 아니라 값이므로, 올바른
하위 타입은 받아들여집니다.

파라미터가 있는 등록을 그냥 `get<T>()`로 해석하면 `CobaltParamRequiredError`를 던집니다. 인자가 올 곳이
없기 때문입니다.


### 비동기로 빌드

빌드가 무언가를 기다려야 한다면(id로 불러오는 문서, 한 계정을 위해 여는 세션 등) 비동기 팩토리를 등록하고
`getAsyncWithParam`으로 읽으십시오:

```dart
class DocumentFactory implements CobaltAsyncParamFactory<Document, int> {
  const DocumentFactory();

  @override
  Future<Document> create(CobaltResolver resolver, int id) =>
      resolver.get<DocumentStore>().load(id);
}

scope.registerAsyncParamFactory<Document, int>(const DocumentFactory());

final document = await scope.getAsyncWithParam<Document, int>(42);
```

호출할 때마다 스코프가 보유하지 않는 새 인스턴스를 빌드하며, 호출한 쪽이 그것을 소유합니다. `init()`이
빌드하는 일은 없으므로 나중에 등록해도 되며, `dependsOn`으로 이를 기다리는 것도 없습니다. 그 팩토리는
`getAsync`로 지연 등록을 기다릴 수 있으며, 자신의 await를 거쳐 지금 빌드 중인 키를 요청하는 빌드는 멈춰
버리는 대신 `CobaltCycleError`가 됩니다. `getWithParam`으로 해석하면 `CobaltAsyncParamError`를 던집니다.
반대로 일반적인 파라미터가 있는 등록에 `getAsyncWithParam`을 쓰면 `getWithParam`이 돌려줄 것을 그대로
돌려줍니다. 테스트에서는 `CobaltAsyncParamOverride`가 이를 교체합니다.

---

## 10. 선택적 의존성

```dart
class ReportFactory implements CobaltFactory<Report> {
  const ReportFactory();

  @override
  Report create(CobaltResolver resolver) =>
      Report(resolver.get<Clock>(), resolver.getOrNull<Telemetry>());
}
```

`getOrNull`은 "아무것도 등록되어 있지 않음"일 때만 null을 반환합니다. `init()` 전에 요청한 비동기 싱글턴은
여전히 예외를 던지고, 인자 없이 요청한 파라미터가 있는 등록도 마찬가지입니다. "준비되지 않음"과 "존재하지
않음"은 서로 다른 사실이기 때문입니다. 둘을 하나로 합치면 시작 순서 버그가 부재로 읽히는 값으로 바뀌어
버립니다.

---

## 11. 그래프 하나, 여러 빌드

한 빌드가 다른 빌드와 정말로 다른 구현을 필요로 하기 전까지는 이 절을 건너뛰십시오. 그때까지 여러분의
그래프에는 환경이 정확히 하나뿐이고, 여기 있는 내용은 해당되지 않습니다.

`CobaltEnvironment.matches`는 평범한 공개 API이므로, 선택은 `if` 하나입니다:

```dart
class AppScope implements CobaltScopeBuilder {
  const AppScope(this.environment);

  final CobaltEnvironment environment;

  @override
  void build(CobaltScope scope) {
    scope.registerLazySingleton<EventLog>(const EventLogFactory());

    if (environment.matches(const {'dev', 'test'})) {
      scope.registerLazySingleton<ApiClient>(const FakeApiClientFactory());
    }
    if (environment.matches(const {'prod', 'stage'})) {
      scope.registerLazySingleton<ApiClient>(const LiveApiClientFactory());
    }
  }
}
```

`dev`, `stage`, `prod`, `test`는 상수일 뿐 닫힌 집합이 아닙니다. `CobaltEnvironment('canary')`도 똑같이
동작합니다. 여러 환경을 한 번에 활성화하거나 이름이 아닌 다른 무언가로 매칭하려면 하위 클래스를 만들어
`matches`를 오버라이드하십시오.

여기서는 아무것도 이 분기를 대신 검사해 주지 않습니다. 둘 다 참인 `if` 두 개는 같은 키를 두 번 등록해 시작할
때 예외를 던지고, 둘 다 거짓이면 그 타입이 등록되지 않은 채 남아 첫 해석이 그 사실을 알리며 실패합니다.
이것이 이 모드의 대가입니다. 다른 모드는 둘 다 빌드 시점에 거부합니다.

---

## 12. 그래프 관찰하기

옵저버는 스코프가 생기고, 인스턴스가 빌드되고, 시작이 끝나고, 해제가 실패하는 것을 봅니다. 그래프를 만드는
곳에서 넘기십시오. 그 아래로 push되는 모든 스코프가 이를 물려받습니다.

```dart
final app = await CobaltApplication.start(
  root: const AppScope(),
  observers: [CobaltLogObserver(const CobaltPrintLogSink())],
);
```

`CobaltPrintLogSink`는 stdout에 기록하며, 앱 밖에서는 이것이 알맞은 기본값입니다. Flutter 앱에는
`CobaltDeveloperLogSink`(`dart:developer`)가 맞습니다. `push(name, observers: [...])`로 하위 트리 하나에
옵저버를 더 추가할 수 있습니다.

콜백은 살아 있는 객체가 아니라 설명인 `CobaltScopeRef`와 `CobaltKey`를 받으며, 콜백에서 발생한 예외는
삼켜집니다. 지켜보는 쪽이 지켜보는 대상을 망가뜨릴 수 있어서는 안 됩니다. 해석은 보고되지 않습니다. 캐시
적중은 핫 패스이며, 볼 가치가 있는 것은 인스턴스가 *빌드되는* 순간입니다.
빌드마다 시간을 잽니다. `onInstanceBuilt`가 `onInstanceCreated` 다음에 걸린 시간과 함께 호출되며(그 빌드가
해석한 빌드와 모든 `await`를 포함한 전체 경과 시간), 로그 옵저버는 이를 같은
줄에 기록합니다.

`CobaltLogObserver`는 따로 지정하지 않으면(`minimumLevel`) `debug` 이상을 남깁니다. 인스턴스별 기록은
`trace`이므로 큰 그래프도 로그를 뒤덮지 않습니다. 버리는 기록은 아예 포맷되지 않으므로(기록을 만들기 전에
레벨을 묻습니다), 레벨을 낮추기 전까지는 연결된 로그의 빌드당 비용이 거의 없습니다. 직접 만든
`CobaltRecordingObserver`도 `accepts(level)`을 오버라이드하면 같은 효과를 얻습니다.

### 어딘가로 보내기

| 패키지 | 형태 |
|---|---|
| `cobalt_talker` | 옵저버, 이벤트 계열마다 색이 다른 로그 타입 하나 |
| `cobalt_logging` | dart.dev `logging` 위의 싱크 |
| `cobalt_logger` | `logger` 위의 싱크 |

그 밖의 것은 콜백 하나로 되므로, 어댑터 패키지가 없어서 쓸 수 없는 로거는 없습니다:

```dart
CobaltLogObserver(CobaltLogSink.from((r) => myLogger.debug(r.message)))
CobaltLogObserver(CobaltLogSink.from((r) => gelf.send(r.toStructured())))
```

기록은 단순한 문자열이 아닙니다. `level`, `scope`, `key`, `error`, `stackTrace`, `kind`가 모두 들어 있으며,
`kind`는 파싱해야 하는 문장이 아니라 `CobaltEventKind.scopeInitFailed` 같은
값입니다.

### 크래시 리포트는 형태가 다릅니다

리포트를 쓸모 있게 만드는 것은 예외가 아니라, 그 직전에 그래프가 무엇을 하고 있었는지입니다.

```dart
observers: [
  CobaltErrorObserver(
    CobaltErrorSink.from((report) => Sentry.captureException(
      report.error,
      stackTrace: report.stackTrace,
      withScope: (scope) => scope.setContexts('cobalt', report.toStructured()),
    )),
  ),
],
```

경위는 모든 레벨에서 보관되는 기록 20개짜리 링 버퍼이며, 로그 싱크가 버리는 인스턴스별 기록도 포함합니다.
임계값은 `warning`이 아니라 `error`입니다. 해제 실패는 분명 누수를 뜻하지만, 사소한 문제마다 유료 서비스로
알림을 보내면 아무도 리포트를 읽지 않게 됩니다. `reportAt`으로 낮출 수 있습니다.

### 앱이 실행되는 동안 화면에서

```dart
final log = CobaltInspectorLog();

// observers: [log]

CobaltInspectorScreen(log: log, scope: context.cobaltScope)
```

탭은 세 개입니다. 각 등록의 수명과 소유자가 표시되는 실시간 스코프 트리, 실제로 빌드된 것(각 빌드에 걸린
시간과 함께, 느린 것은 표시됨), 그리고 검색하고 일시 정지할 수 있는, 보고된 모든 것입니다. 트리를 열어도
아무것도 빌드되지 않습니다. 보여 주려고 지연 싱글턴을 실체화하면 보러 온 대상 자체가 바뀌어 버리기 때문입니다.

---

## 13. 테스트

가장 먼저 알아야 할 것은 API가 아니라 함정입니다. `testWidgets`는 본문을 fake-async 존 안에서 실행하며,
그 안에서는 초기화의 `Future.delayed`가 영원히 완료되지 않습니다. **그래프는 `setUp`에서 빌드하고**, 그래프
전체에 대한 단언은 평범한 `test`에 두십시오.

```dart
late CobaltScope scope;

setUp(() async {
  scope = await cobaltTestScope(root: const AppScope());
});
```

`cobaltTestScope`와 `cobaltTestRoot`는 테스트와 함께 해제됩니다. 이 부분은 빠뜨리기 쉬운데, 빠뜨리면
테스트가 실패하는 것이 아니라 다음 테스트로 새어 나갑니다.

### 그래프가 완전한지 검사하기

**이것은 다른 어느 곳보다 여기서 중요합니다.** 직접 작성한 팩토리는 `create` 안에서 해석하므로, 그것이
무엇을 요청할지 정적으로 알 수 있는 방법이 없습니다. 빠진 등록은 런타임 실패이며, 그것을 처음 해석하게 된
화면에서 드러납니다. 그래프를 실행해 보는 것이 유일한 검사입니다:

```dart
await expectGraphResolves(scope);
```

첫 번째 키만이 아니라 빌드하지 못한 모든 키를 보고합니다. 이 검사는 되돌릴 수 없습니다. 해석하는 것 *자체가*
검사이므로, 그 뒤에는 모든 지연 싱글턴이 빌드되어 있고 해제 순서도 달라집니다. 별도의 테스트에
두십시오.

파라미터가 있는 등록은 값 없이는 해석할 수 없으므로, 조용히 건너뛰는 대신 이름과 함께 `unchecked`로
보고됩니다. 실제로 검사하려면 예시 값을 넘기십시오:

```dart
await expectGraphResolves(scope, params: {CobaltKey(Counter): 'alice'});
```

Manual Mode 그래프를 만든 첫날부터 이 테스트를 테스트 모음에 포함하십시오. 다른 모드가 컴파일러로부터 얻는
것이 바로 이것입니다.

### 그래프의 형태 지키기

완전성 검사는 그래프가 해석된다는 것을 말해 주고, 스냅숏은 그래프가 여전히 이전과 같은 모습이라는 것을
말해 줍니다. `describeGraph`는 각 스코프의 등록(종류, 재정의, 데코레이터)을 아무것도 빌드하지 않고
렌더링하며, `expectGraphSnapshot`은 그것을 테스트 옆에 보관한 파일과 비교합니다:

```dart
test('the graph keeps its shape', () async {
  final app = await cobaltTestScope(root: const AppScope(), rootName: 'app');
  expectGraphSnapshot(app, 'test/app_graph.snapshot');
});
```

```text
scope "app"
  Clock — lazySingleton
  Greeter — lazySingleton
  GreetingStore — lazySingleton, decorated: Logging
```

등록이 추가되거나, 수명이 바뀌거나, 데코레이터가 추가되면 테스트가 diff와 함께 실패하므로, 변경은 기기에서
발견되는 대신 리뷰에서 읽힙니다. 변경을 받아들이려면 파일을 다시 쓰고(`COBALT_UPDATE_SNAPSHOTS=1 flutter test`
또는 `update: true`) 커밋하십시오. 아직 존재하지 않는 스냅숏도 작성되고 통과하는 대신 실패합니다. CI에서
그렇게 되면 아무것도 검사하지 않는 셈이기 때문입니다. 파일을 읽고 쓰려면 파일 시스템이 필요합니다. 웹에서는
`describeGraph(scope)`를 문자열과 비교하십시오.

키는 자신이 빌드하는 것을 가릴 수 있습니다. `ApiClient`가 한 빌드에서는 `FakeApiClient`이고 다른 빌드에서는
`LiveApiClient`입니다. 팩토리가 알려 주면 스냅숏은 이를 `ApiClient — lazySingleton, as LiveApiClient`로
보여 주며, 스코프가 `adopt`한 것(시작 시 실행된 부트스트랩 단계)을 `adopted: BindPlatform, ReportCrashes`로
나열합니다. 환경마다 스냅숏을 하나씩 두면 리뷰에서 빌드 간 차이를
볼 수 있습니다:

```dart
test('each environment keeps its shape', () async {
  await expectGraphSnapshots(
    (environment) => cobaltTestScope(
      root: $CobaltRootScope(environment: environment),
      bootstrap: $cobaltBootstrap(environment),
      rootName: $cobaltRootScopeName,
    ),
    environments: {CobaltEnvironment.dev, CobaltEnvironment.prod},
    directory: 'test/snapshots',
  );
});
```

환경마다 파일이 하나씩(`test/snapshots/dev.txt`, `prod.txt`) 생기며, 실패하기 전에 모든 환경을 검사하고,
실패 메시지는 바뀐 환경을 하나하나 지목합니다. `examples/notes_app`은 네 개를 유지합니다.

`describeGraphMermaid(scope)`는 같은 사실을 Mermaid 순서도(flowchart)로 그립니다. 스코프는 중첩된 subgraph로,
등록은 상자로 그려지며, GitHub가 README나 풀 리퀘스트에서 렌더링하는 `mermaid` 코드 블록에
쓸 수 있습니다.

생성된 팩토리는 항상 무엇을 빌드하는지 알려 줍니다. 직접 작성한 팩토리는 `CobaltDescribedFactory`를 구현해
알려 주며, 구현하지 않으면 그 줄은 이전과 같이 표시됩니다.

### 재정의

대체할 것은 키를 소유한 스코프에 넘기십시오. 재정의는 스코프가 생성될 때 가장 먼저 등록되며, 같은 키의
실제 등록은 중복으로 거부되는 대신 건너뜁니다. 그래서 그 스코프의 모든 팩토리가 대체된 것을
해석합니다:

```dart
final scope = cobaltTestRoot(
  overrides: [CobaltOverride<Clock>.value(FixedClock(DateTime(2026)))],
)..runBuilder(const AppScope());
```

`.value`는 빌드된 객체를, `.lazy`와 `.transient`는 팩토리를, `CobaltParamOverride<T, P>`는 파라미터가 있는
팩토리를 받습니다. `cobaltTestScope(overrides:)`와 `CobaltApplication.start(overrides:)`는 같은 리스트를
받습니다. `CobaltAppScope(overrides: () => [...])`는 시작할 때마다 호출되는 함수를 받으므로, 재시작해도 이전
그래프가 이미 닫은 값을 다시 받지 않습니다. 앱에서는 플레이버나 디버그 메뉴가 이런 경우입니다.
재정의는 결코 조용히 일어나지 않습니다. 옵저버는 `onRegistrationOverridden`을 받고, `overriddenKeys`는
무엇이 교체되었는지 나열합니다.

`CobaltScopeWidget`, 스코프를 가진 위젯들, 플로우를 소유하는 모든 라우트도 스코프가 생성될 때마다 호출되는
함수 형태로 `overrides`를 받습니다. 위젯 테스트에서 대역을 끼운 채 화면 하나를 마운트하는 방법이 이것입니다.
이것들은 해당 스코프가 등록하는 것을 교체합니다. 조상이 소유한 키는 조상에서 재정의하며, 자식에게 이를
요청하면 소유자를 지목하며 실패합니다.

빌드 비용이 큰 즉시 생성 싱글턴은 `registerEagerSingleton`으로 등록하십시오. `registerSingleton`에 넘긴 값은
스코프가 거절하기 전에 이미 존재하므로, 재정의되면 스코프가 보유하다가 함께 닫지만 해석되는 일은 없습니다.
`registerEagerSingleton`이면 스코프가 직접 빌드하므로 빌드를
건너뛸 수 있습니다.

타입 인자를 명시하십시오. 리스트 안에서는 Dart가 이를 `Object`로 추론하며, 스코프는 생성되자마자 이를
거부합니다. 따로 작성하면 대체하는 쪽의 타입(`Clock`이 아니라 `FixedClock`)으로 추론되며, `runBuilder`는
아무것도 교체하지 않은 재정의를 보고합니다.

자식 스코프에서의 섀도잉이 다른 방법이며, 프로덕션에서 세션과 플로우에 쓰는 방법이 이것입니다:

```dart
final child = scope.pushForTest()
  ..registerSingleton<Clock>(FixedClock(DateTime(2026)));
```

이것은 자식에서 해석되는 것에만 닿습니다. **팩토리는 자기 등록을 소유한 스코프에서 실행되므로**, 위에 등록된
소비자는 실제 의존성을 계속 씁니다. `ownerOf<T>()`가 테스트보다 먼저
답해 줍니다:

```dart
expect(scope.ownerOf<Greeter>(), same(scope.root));   // 루트가 소유하므로 루트에서 재정의합니다
```

### 픽스처

```dart
final scope = cobaltTestRoot()
  ..registerLazySingleton<Clock>(FnFactory((_) => FixedClock(DateTime(2026))))
  ..registerSingleton<Config>(const Config())
  ..registerAsyncSingleton<Db>(AsyncFnFactory((_) async => Db()))
  ..registerParamFactory<Counter, String>(FnParamFactory((_, id) => Counter(id)));

await scope.init();
```

이 네 가지 덕분에 스텁마다 팩토리 클래스를 작성하지 않아도 됩니다. 비동기 등록은 `init()` **전에** 존재해야
하므로, 픽스처는 이미 시작된 스코프가 아니라 새 루트에
넣습니다.

`DisposeRecorder`는 해제를 단언하기 위한 픽스처로, 공유 로그가 아니라 인스턴스마다 로그를 가지므로, 자신을
만든 테스트가 끝난 뒤에 해제된 스코프가 다음 테스트에 기록을 남길 수 없습니다:

```dart
final recorder = DisposeRecorder();
scope.registerLazySingleton<Disposable>(recorder.factory('cache'));
scope.get<Disposable>();

await scope.dispose();
expect(recorder.entries, ['cache']);
```

`CapturingObserver`는 그래프가 한 일에 대해 단언할 수 있도록 이벤트를 모읍니다.

### 위젯 테스트

`cobalt_test_flutter`에는 뻔해 보이는 작성법이 틀린 두 가지 경우를 위한 헬퍼가 있습니다:

```dart
await settle(tester);                    // pumpAndSettle이 아닙니다: 로딩 인디케이터에서 영원히 돕니다
final scope = mountedRootScope(tester);  // 앱의 그래프, MaterialApp builder 아래에서 가져옵니다
```

`examples/testing_patterns`는 `test/` 디렉터리 자체가 핵심인 패키지입니다.

---

## 14. 미리 알아 둘 만한 실수

아래는 모두 이 저장소에서, 또는 이 저장소가 작성된 대상 애플리케이션에서 직접 겪으며 알게 된 것입니다.

- **테스트 모음에 `expectGraphResolves`가 없음.** 이 모드에서는 그 밖에 그래프가 완전한지 검사하는 것이
  없습니다. 빠진 등록이 그대로 배포되어 어느 화면에서 실패합니다.
- **`testWidgets` 안에서 그래프 빌드.** fake-async, 완료되지 않음, 가리킬 대상이 없는 타임아웃.
  `setUp`을 쓰십시오.
- **소비자보다 아래에서 재정의.** 팩토리는 소유한 스코프에서 실행됩니다. `ownerOf<T>()`가 단언보다 먼저
  알려 줍니다.
- **해석하지 않고 캡처하는 팩토리.** 협력 객체는 팩토리를 작성한 위치에서 보이는 변수가 아니라 `create`에
  넘겨진 `resolver`에서 읽으십시오. 그렇지 않으면 두 번째 시작이 첫 번째 그래프의 객체를
  재사용합니다.
- **`CobaltScopeBuilder.build` 안에서 해석.** 이것은 스코프가 아직 기술되는 중에 실행됩니다.
  거기서는 등록하고, 해석은 나중에 하십시오.
- **`bootstrap`을 저장된 리스트로 넘김**, `CobaltAppScope`로 루트를 소유하는 경우. 단계는 리소스를
  보유하며, 재시작하면 새 단계를 받아야 합니다. 함수를 넘기십시오.
- **스코프가 소유한 bloc에 `BlocProvider(create:)` 사용.** 소유자가 둘이 되고, 위젯이 먼저 이깁니다.
  `BlocProvider.value`를 쓰십시오.
- **닫을 수 있다고 명시하지 않고 등록한 `ChangeNotifier`나 `Cubit`.** 빌드되고, 사용되고, 조용히 영영
  닫히지 않습니다. `implements Disposable`, `with CobaltBloc`, 또는 `dispose:`를 쓰십시오.
- **PATH에서 먼저 잡히는 오래된 `dart`.** 엉뚱한 곳에서 조용히 실패합니다. 실행 결과를 믿기 전에
  `dart --version`을 확인하십시오.

---

## 15. 제너레이터를 추가할 시점

그러기 위해 여기 있는 것을 버릴 필요는 없습니다. 생성된 컨테이너도 위에서 본 것과 같은 `CobaltScopeBuilder`이므로,
이미 작성한 것과 함께 조합됩니다:

```dart
class AppScope implements CobaltScopeBuilder {
  const AppScope();

  @override
  void build(CobaltScope scope) {
    $CobaltRootScope().build(scope);          // 제너레이터가 찾은 것
    scope.registerSingleton<Config>(config); // 제너레이터가 알 수 없는 것
  }
}
```

그래프가 커지면 빌드 단계를 둘 만한 이유가 세 가지 있습니다:

- **빌드 시점의 완전성 검사**: 테스트 시점에 `expectGraphResolves`로 하던 검사를 대신합니다.
- **프로퍼티 주입**: 협력 객체가 다섯 개 이상으로 늘어난 생성자를 비웁니다.
- **린트 규칙 열여덟 개**: §14의 실수를 에디터에서 잡아냅니다.

그대로 유지되는 것: 스코프, 해제, 두 단계, 파라미터가 있는 등록, 관측성, 테스트. 이어지는 내용은
[GUIDE_CODEGEN.ko.md](GUIDE_CODEGEN.ko.md)가 다루며, `get_it`이나 `injectable`에서 옮겨 오는 경우는
[MIGRATION.ko.md](MIGRATION.ko.md)가 다룹니다.
