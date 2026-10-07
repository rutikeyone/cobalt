<p align="center">
  <a href="TROUBLESHOOTING.md">English</a> · <a href="TROUBLESHOOTING.ru.md">Русский</a> · <a href="TROUBLESHOOTING.zh-CN.md">中文</a> · <a href="TROUBLESHOOTING.ko.md">한국어</a>
</p>

> 이 문서는 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)를 번역한 것입니다. 영어판이 기준이며, 내용이
> 다르면 영어판을 따릅니다. 오류 메시지의 링크는 영어판으로 연결됩니다. 제목은 영어판과 같으므로 오류
> 이름으로 검색하면 해당 항목을 찾을 수 있습니다.

# 자주 만나는 오류

Cobalt가 실행 중에 던지는 모든 오류는 이 페이지의 해당 항목으로 가는 링크로 끝납니다. 각 항목은 오류가
언제 생기는지, 어떻게 해야 하는지를 설명합니다.

- [그래프에서 읽기](#그래프에서-읽기)
- [등록](#등록)
- [시작과 종료](#시작과-종료)
- [Flutter에서](#flutter에서)
- [`build_runner`가 실패할 때](#build_runner가-실패할-때)

## 그래프에서 읽기

### CobaltNotRegisteredError

```
Config is not registered in scope "app" or its ancestors. Resolving: Api -> Repository -> Config.
```

현재 스코프부터 루트까지 어떤 스코프도 등록하지 않은 타입을 요청했습니다.

- 제너레이터 사용 시: 클래스에 `@cobaltInject`를 붙이고 `dart run build_runner build`를 다시 실행합니다.
  생성된 컨테이너 밖에서 직접 등록하는 타입이라면 `@CobaltScopeRoot(provides: [...])`에 적습니다.
- 직접 등록 시: 그 스코프의 `build()`나 상위 스코프에서 등록합니다.
- `Resolving:`은 누가 요청했는지 처음부터 끝까지 보여 줍니다. 첫 번째 이름부터 살펴보십시오.
- 메시지에 스코프가 아직 빌드 중이라고 나온다면: eager `registerSingleton`이 `build()` 아래쪽의 등록보다
  먼저 의존성을 해결했습니다. 그 등록들 아래로 옮기거나 lazy로 바꾸십시오.
- 스코프는 자기 자신과 상위 스코프만 봅니다. 세션이나 화면 스코프에 등록한 타입은 루트에서 보이지 않습니다.

### CobaltNotReadyError

비동기 등록(`registerAsyncSingleton` 또는 `@CobaltInit` 클래스)을 `init()`이 빌드를 마치기 전에
읽었습니다.

- 시작을 기다리십시오: `await CobaltApplication.start(...)` 또는 `await $startCobalt()`. Flutter에서는
  그래프가 준비될 때까지 `CobaltAppScope`가 `loading`을 보여 주므로, `runApp` 전이 아니라 앱 안에서
  읽으십시오.
- 직접 push한 스코프라면 읽기 전에 `await child.init()`을 실행하십시오.

### CobaltLazyAsyncError

지연 비동기 등록(`registerLazyAsyncSingleton` 또는 지연 `@CobaltInit` 클래스)을 아무도 빌드하기 전에
`get`으로 읽었습니다.

- `await scope.getAsync<T>()`를 사용하십시오. 첫 호출이 빌드하고, 이후 호출은 같은 인스턴스를 받습니다.
  위젯에서는 `CobaltAsyncBuilder`가 기다리는 일을 맡습니다.
- 화면이 열릴 때 이미 준비되어 있어야 한다면 `warmUp`으로 미리 시작하십시오.

### CobaltAsyncTransientError

비동기 트랜지언트(`registerAsyncFactory`, 또는 `@CobaltInit` 클래스의 `@cobaltTransient`)에 `get`을
호출했습니다. 호출할 때마다 새로 빌드되므로 매번 기다려야 합니다.

- `await scope.getAsync<T>()`를 사용하고, 목록이라면 `getAllAsync`를 사용하십시오. 린트 규칙
  `cobalt_async_transient_read_synchronously`가 편집기에서 이 위치를 알려 줍니다.

### CobaltParamRequiredError

이 등록은 호출하는 쪽에서 값을 받아야 하는데(`registerParamFactory` 또는 `@CobaltParam` 클래스), 값 없이
읽었습니다.

- `scope.getWithParam<T, P>(value)`를 사용하고, 비동기로 빌드된다면 `getAsyncWithParam`을 사용하십시오.
  위젯에서는 `context.cobaltWithParam<T, P>(value)`입니다.

### CobaltNotParameterizedError

반대 경우입니다. 파라미터를 받지 않는 등록에 `getWithParam`을 호출했습니다.

- `get<T>()`를 사용하십시오.

### CobaltAsyncParamError

파라미터로부터 비동기로 빌드되는 등록(`registerAsyncParamFactory`)에 `getWithParam`을 호출했습니다.

- `await scope.getAsyncWithParam<T, P>(value)`를 사용하십시오.

### CobaltParamTypeError

`getWithParam`에 넘긴 값이 등록이 받는 타입과 다릅니다. 대개 필드 이름이나 순서가 다른 record입니다.

- 선언된 타입을 정확히 넘기십시오. 제너레이터를 쓴다면 생성된 `$<Class>Args` record를 만드십시오.

### CobaltCycleError

```
Dependency cycle detected: Session -> Api -> Session
```

목록의 등록들이 서로를 필요로 하므로 어느 것도 먼저 빌드할 수 없습니다.

- 순환을 끊으십시오. 양쪽이 필요로 하는 부분을 세 번째 클래스로 옮기거나, 한쪽이 상대를 생성자가 아니라
  사용하는 시점에 해결하도록 하십시오.
- 제너레이터를 쓰면 순환이 있을 때 빌드가 실패하고, 린트 규칙 `cobalt_dependency_cycle`이 편집기에서
  보여 줍니다.

## 등록

### CobaltDuplicateRegistrationError

같은 타입이 같은 이름으로 한 스코프에 두 번 등록되었습니다.

- 하나를 지우십시오.
- 한 타입의 구현을 여러 개 두려면 각각 이름을 붙이고(등록할 때 `name: 'audit'`, 읽을 때
  `get<Logger>(name: 'audit')`), 전부 한 번에 읽을 때는 `getAll<T>()`를 사용하십시오.
- 테스트나 flavor에서 등록을 바꾸려면 두 번째 등록이 아니라 override를 사용하십시오.

### CobaltScopeStateError

스코프가 이 호출에 맞지 않는 상태입니다. 메시지에 어떤 상태인지, 무엇을 요청했는지 나옵니다.

- **`init()`이 시작된 뒤의 비동기 등록.** `init()`은 시작할 때 찾은 비동기 등록만 가져가며 한 번만
  실행됩니다. `init()` 전에 등록하십시오. 나중에 추가하려면 자식 스코프를 push하고 거기서 등록한 뒤
  `await child.init()`을 실행하십시오.
- **`dispose()` 이후 또는 도중에 스코프를 사용.** 무언가가 오래된 스코프의 참조를 들고 있습니다. 흔히
  이미 로그아웃한 세션입니다. 현재 스코프에서 읽으십시오.

### CobaltDependsOnError

`dependsOn`이 `init()`이 빌드하지 않는 것을 가리킵니다. 아무도 등록하지 않은 타입, 일반 등록, 지연 등록,
비동기 팩토리가 그렇습니다. `dependsOn`은 `init()` 안에서 비동기 싱글턴의 순서만 정하므로 여기서는 기다릴
것이 없습니다.

- 아무도 등록하지 않았다면 등록하십시오. [CobaltNotRegisteredError](#cobaltnotregisterederror)와 같은
  방법입니다.
- 그 외에는 `dependsOn`에서 빼십시오. 일반 의존성은 필요할 때 해결되고, 지연 등록은 첫 `getAsync`가,
  비동기 팩토리는 매 `getAsync`가 빌드합니다.

### CobaltOverrideError

override가 아무것도 바꾸지 않았습니다.

- **타입 인자가 없음.** `CobaltOverride.value(FakeClock())`는 `FakeClock`을 바꾸고, 목록 안에서는
  `Object`를 바꿉니다. 등록된 타입을 적으십시오: `CobaltOverride<Clock>.value(FakeClock())`. 린트 규칙
  `cobalt_override_needs_type_argument`가 잡아 줍니다.
- **잘못된 스코프.** 그 타입은 다른 스코프에 등록되어 있으며, 메시지가 그 스코프를 알려 줍니다. override를
  그곳에 두어야 그 타입을 쓰는 팩토리도 교체된 것을 봅니다.

### CobaltDecoratorError

데코레이터를 너무 늦게 추가했거나, 감쌀 것이 없습니다.

- **너무 늦음:** 인스턴스가 이미 넘겨졌고, 그것을 가진 쪽은 데코레이트되지 않은 인스턴스를 계속 씁니다.
  등록과 같은 `build()`에서, 누군가 해결하기 전에 데코레이터를 추가하십시오.
- **감쌀 것이 없음:** 이 스코프는 그 키를 등록하지 않습니다. 다른 스코프가 등록한다면 메시지가 그 스코프를
  알려 줍니다. 그곳에서 데코레이트하십시오.

### CobaltHookError

스코프나 그 아래 스코프가 이미 인스턴스를 빌드한 뒤에 `hookAll`을 호출했습니다. 그 인스턴스들은 훅을
통과하지 않습니다.

- 훅은 스코프를 구성하는 곳에서, 어떤 `get`이나 eager 등록보다 먼저 추가하십시오. 린트 규칙
  `cobalt_hook_added_too_late`가 한 블록 안에서 이를 잡아 줍니다.

## 시작과 종료

### CobaltBootstrapError

부트스트랩 단계(`@CobaltBootstrap` 또는 `CobaltBootstrapStep`)가 예외를 던졌습니다. 메시지에 단계
이름과 원래 오류가 담기며, `cause`와 `causeStackTrace`에 보관됩니다.

- 원래 오류를 고치십시오. Flutter에서는 `CobaltAppScope`가 다시 시도 버튼이 있는 `errorBuilder`를
  보여 줍니다.

### CobaltInitTimeoutError

시작이 `init(timeout:)` 또는 `initTimeout:`을 넘겼습니다. 메시지에 아직 빌드되지 않은 것이 모두 나옵니다.

- 왜 느린지 찾으십시오. 자체 타임아웃이 없는 네트워크 호출이 흔한 원인입니다.
- 첫 화면에 필요 없는 것은 시작 과정에서 뺄 수 있습니다. 지연 등록(`registerLazyAsyncSingleton`)으로
  바꾸고 처음 쓸 때 빌드하십시오.
- 또는 타임아웃을 늘리십시오.

### CobaltWarmUpError

`warmUp`이 일부 등록을 빌드하지 못했습니다. 메시지에 각각의 오류가 나옵니다. 나머지는 빌드되었고, 실패한
것은 다음 `getAsync`에서 다시 시도합니다.

- 나열된 오류를 고치십시오. `getAsync`가 던졌을 것과 같은 오류입니다.

### CobaltDisposeError

스코프는 해제되었지만 일부 객체가 깔끔하게 닫히지 않았습니다. `dispose()`가 예외를 던졌거나 기한을
넘겼습니다. 메시지에 모든 실패가 나오며, `hasTimeout`으로 타임아웃과 오류를 구별합니다.

- 예외를 던진 `dispose()`를 고치십시오. 나머지는 모두 닫혔습니다.
- 타임아웃이라면 느린 `dispose()`를 빠르게 하거나 해제에 시간을 더 주십시오:
  `scope.dispose(timeout: ...)`. 기본값은 트리 전체에 30초입니다.

## Flutter에서

### CobaltNoScopeError

`context.cobalt<T>()`가 위젯 위에서 스코프를 찾지 못했습니다.

- README의 빠른 시작처럼 `CobaltAppScope`를 `MaterialApp.builder`에 넣거나, 하위 트리를
  `CobaltScopeWidget`으로 감싸십시오.
- `Navigator.push`로 연 라우트는 내비게이터가 빌드하며, 그 위치는 라우트를 연 화면보다 위입니다. 그래서
  그 화면이 소유한 스코프를 볼 수 없습니다. 새 화면에 스코프를 넘기거나, 스코프를 내비게이터 위에
  두십시오.

### CobaltNoAppScopeError

`restart()`에 쓰는 `CobaltAppScope.of(context)`가 위젯 위에서 `CobaltAppScope`를 찾지 못했습니다.

- 앱을 `CobaltAppScope`나 `CobaltAppScope.builder`로 시작하십시오. `CobaltScopeProvider`는 다른 쪽이
  소유한 스코프를 공개할 뿐이라 다시 시작할 수 없습니다.

## `build_runner`가 실패할 때

제너레이터는 무엇을 바꿔야 하는지 알려 주는 메시지와 함께 빌드를 멈춥니다. 흔한 경우는 다음과 같습니다.

- **아무도 등록하지 않은 의존성.** [CobaltNotRegisteredError](#cobaltnotregisterederror)와 같은 방법으로
  고칩니다. 클래스에 어노테이션을 붙이거나 `@CobaltScopeRoot(provides: [...])`에 적으십시오. 메시지는
  빠진 것을 한 번에 모두 보여 줍니다.
- **한 패키지에 `@CobaltScopeRoot` 클래스가 둘.** 패키지마다 생성된 루트는 하나입니다. 하나만 남기십시오.
- **의존성 순환.** [CobaltCycleError](#cobaltcycleerror)를 참고하십시오.
- **`@CobaltInject`가 붙은 추상 클래스나 제네릭 클래스.** 제너레이터가 빌드할 수 없습니다. 구체 클래스에
  어노테이션을 붙이고 인터페이스로 노출하십시오: `@CobaltInject(exposeAs: ApiClient)`.

검사가 어떻게 동작하는지는 [GUIDE_CODEGEN.ko.md](../GUIDE_CODEGEN.ko.md#5-그래프는-완전해야-합니다)에,
[린트 플러그인](../GUIDE_CODEGEN.ko.md#16-린트-플러그인)은 빌드 전에 편집기에서 이 중 대부분을 보여 줍니다.
