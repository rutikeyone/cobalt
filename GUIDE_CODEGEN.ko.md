<p align="center">
  <a href="GUIDE_CODEGEN.md">English</a> · <a href="GUIDE_CODEGEN.ru.md">Русский</a> · <a href="GUIDE_CODEGEN.zh-CN.md">中文</a> · <a href="GUIDE_CODEGEN.ko.md">한국어</a>
</p>

> 이 문서는 [GUIDE_CODEGEN.md](GUIDE_CODEGEN.md)를 번역한 것입니다. 영어판이 기준이며, 내용이 다르면 영어판을 따릅니다.

# Code-Gen Mode (코드 생성 모드)

제너레이터와 함께 쓰는 Cobalt입니다. 여러분은 클래스에 어노테이션을 붙이고, `build_runner`가 컨테이너를 작성하며,
그래프는 빌드되기 전에 검사됩니다. 생성되는 것은 `cobalt`의 공개 API 외에는 아무것도 사용하지 않는 평범한 Dart
코드입니다. 읽을 수 있고, 그 안의 모든 것은 직접 작성할 수도 있었던 것입니다.

이것은 프로젝트의 변함없는 불변 조건이며, 여러분이 실제로 활용하게 될 결과가 하나 있습니다. 생성된 컨테이너도
다른 것과 다를 바 없는 `CobaltScopeBuilder`이므로, 직접 작성한 등록이 하나의 그래프 안에서 그것과 함께
조합됩니다. 여기에는 전부 아니면 전무인 것이 없습니다.

빌드 단계로 얻는 것이자, 이 문서가 주로 다루는 내용입니다:

- **빌드 시점에 검사되는 그래프**: 아무것도 등록하지 않은 의존성은 그것을 처음 해석하는 화면에서 실패하는 대신
  빌드를 실패시키며, 빠진 것을 한 번에 모두 알려 줍니다.
- **프로퍼티 주입**: `late final` 필드를 생성된 믹스인이 채우므로, 협력 객체가 다섯 개인 클래스도 생성자가
  비어 있습니다.
- **린트 규칙 열여덟 개**: 나머지를 에디터에서 잡아냅니다.

이 중 아무것도 필요하지 않거나 기존 컨테이너를 점진적으로 마이그레이션하는 중이라면, 제너레이터 없이도 모든 것이
동작합니다: [GUIDE_MANUAL.ko.md](GUIDE_MANUAL.ko.md).

---

## 목차

**첫 앱이라면 1, 2, 7, 8절을 읽으십시오.** 설치, 어노테이션, 앱 시작, 위젯에서 읽기까지입니다.
[`examples/hello`](examples/hello)가 바로 그 내용을 파일 하나에 담고 있습니다. 나머지는 필요할 때 읽으면
됩니다. 각 절은 질문 하나에 답합니다.

**그다음 순서:** 나만의 스코프(갤러리의 「세션 스코프」 항목과 [9절](#9-앱보다-먼저-끝나는-스코프)), 그다음
의존성을 바꿔 끼우는 테스트([`examples/testing_patterns`](examples/testing_patterns)와 [18절](#18-테스트))입니다.
[`examples/codegen_basics`](examples/codegen_basics)는 제너레이터가 그 밖에 하는 일, 즉 프로퍼티 주입,
데코레이터, 화면별 스코프를 보여 줍니다.

1. [설치](#1-설치)
2. [처음 생성하는 그래프](#2-처음-생성하는-그래프)
3. [생성되는 코드](#3-생성되는-코드)
4. [프로퍼티 주입](#4-프로퍼티-주입)
5. [그래프는 완전해야 합니다](#5-그래프는-완전해야-합니다)
6. [생성된 루트 위에 조합하기](#6-생성된-루트-위에-조합하기)
7. [Flutter 앱 시작하기](#7-flutter-앱-시작하기)
8. [위젯에서 그래프 읽기](#8-위젯에서-그래프-읽기)
9. [앱보다 먼저 끝나는 스코프](#9-앱보다-먼저-끝나는-스코프)
10. [등록한 것 닫기](#10-등록한-것-닫기)
11. [앱이 시작되기 전에 끝나야 하는 작업](#11-앱이-시작되기-전에-끝나야-하는-작업)
12. [호출하는 쪽에서 오는 값](#12-호출하는-쪽에서-오는-값)
13. [선택적 의존성](#13-선택적-의존성)
14. [직접 작성하지 않은 타입](#14-직접-작성하지-않은-타입)
15. [그래프 하나, 여러 빌드](#15-그래프-하나-여러-빌드)
16. [린트 플러그인](#16-린트-플러그인)
17. [그래프 관찰하기](#17-그래프-관찰하기)
18. [테스트](#18-테스트)
19. [미리 알아 둘 만한 실수](#19-미리-알아-둘-만한-실수)

---

## 1. 설치

런타임은 앱에 포함되어 배포되지만, 제너레이터는 결코 포함되지 않습니다.

```yaml
environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  cobalt: ^1.0.0
  cobalt_flutter: ^1.0.0

dev_dependencies:
  cobalt_generator: ^1.0.0
  build_runner: ^2.15.0
  cobalt_lint: ^1.0.0
  cobalt_test: ^1.0.0
  cobalt_test_flutter: ^1.0.0
```

**하한은 다른 모드와 같습니다.** 그래서 Flutter 3.38의 애플리케이션도 [GUIDE_MANUAL.ko.md](GUIDE_MANUAL.ko.md)에서
시작해 옮겨 올 필요 없이 여기서 바로 시작할 수 있습니다.

함께 따라오는 것이 하나 있습니다. Flutter 3.38에서는 프로젝트의 의존성 해결 결과가 `analyzer 10.0.1`과
`build_runner 2.15.1`이 됩니다. 그곳에서 Flutter가 `meta 1.17.0`을 고정하는데, 더 새로운 analyzer는
`^1.18.0`을 요구하기 때문입니다. 더 새로운 Flutter에서는 대신 12.1.0으로 해결되며, 어느 쪽이든 생성되는 코드는
같습니다. 전체 행은 [docs/OVERVIEW.ko.md](docs/OVERVIEW.ko.md#요구-사항)의 **요구 사항**을 참고하십시오.

순수 Dart 패키지(CLI, 서버, 위젯이 없는 패키지)는 `cobalt_flutter`와 `cobalt_test_flutter`를 뺍니다.
런타임의 어떤 부분도 Flutter를 필요로 하지 않습니다.

어노테이션은 `cobalt`와 함께 들어오며 `cobalt`가 이를 다시 export하므로, import 하나로 둘 다 해결됩니다:

```dart
import 'package:cobalt/cobalt.dart';
```

선택 사항이며 원할 때만 추가합니다: `cobalt_go_router`, `cobalt_bloc`, `cobalt_inspector`, 그리고
`cobalt_talker` / `cobalt_logging` / `cobalt_logger` 중 하나입니다.

---

## 2. 처음 생성하는 그래프

클래스에 어노테이션을 붙이십시오. 의존성은 생성자 파라미터이며, 무엇이 무엇을 해석하는지는 제너레이터가
알아냅니다.

```dart
import 'package:cobalt/cobalt.dart';

@cobaltInject
class Config {
  Config();

  final String environment = 'test';
}

@cobaltInject
class Repository {
  Repository(this.config);

  final Config config;
}

@cobaltInject
class Telemetry implements Disposable {
  Telemetry();

  final events = <String>[];

  void record(String event) => events.add(event);

  @override
  void dispose() => events.clear();
}
```

`@cobaltInject`는 지연 싱글턴입니다. 처음 해석될 때 빌드되고 스코프가 보유합니다. 다른 수명에는 각자의 상수가
있으며, 그 밖의 모든 것은 긴 형태가 받습니다:

| 어노테이션 | 수명 |
|---|---|
| `@cobaltInject` | 지연 싱글턴 |
| `@cobaltSingleton` | 즉시 생성 싱글턴, 그래프가 빌드될 때 빌드됨 |
| `@cobaltTransient` | 해석할 때마다 새 인스턴스, 아무도 보유하지 않음 |

```dart
@CobaltInject(exposeAs: ApiClient, name: 'live', dispose: closeClient)
class LiveApiClient implements ApiClient { ... }
```

`exposeAs`는 클래스를 인터페이스로 등록하며, 소비자가 구현이 아니라 `ApiClient`에 의존하게 되는 것은 이
덕분입니다. `name`은 한정자이므로, 같은 타입을 두 번째로 등록해도 되며 `get<Logger>(name: 'audit')`로 읽습니다.

루트는 패키지 안 어디서든 한 번만 지정하십시오:

```dart
@CobaltScopeRoot(name: 'app')
class AppScope {
  const AppScope();
}
```

그런 다음 생성합니다:

```bash
dart run build_runner build
```

작업하는 동안에는 `dart run build_runner watch`를 쓰십시오. 출력은 커밋하십시오. CI가 다시 생성하고 diff가 있으면
실패하므로, 오래된 생성 코드는 배포되는 대신 이렇게 잡힙니다.

**패키지 하나에 루트 하나입니다.** `cobalt_container`는 패키지 전체를 `$CobaltRootScope` 하나로 집계하므로, 한
패키지 안의 `@CobaltScopeRoot` 클래스 두 개는 생성 오류입니다. 따라서 서로 독립된 생성 그래프 두 개에는 패키지가
두 개 필요합니다. 이 저장소의 예제가 폴더가 아니라 별도의 패키지인 이유가 바로 이것입니다.

---

## 3. 생성되는 코드

결과는 `lib/cobalt.g.dart`이며, 이 모드가 블랙박스로 남지 않도록 한 번쯤 읽어 볼 가치가 있습니다:

```dart
final class _RepositoryFactory implements CobaltFactory<Repository> {
  const _RepositoryFactory();

  @override
  Repository create(CobaltResolver resolver) => Repository(resolver.get<Config>());
}

final class $CobaltRootScope implements CobaltScopeBuilder {
  const $CobaltRootScope();

  @override
  void build(CobaltScope scope) {
    scope.registerLazySingleton<Config>(const _ConfigFactory());
    scope.registerLazySingleton<Telemetry>(const _TelemetryFactory());
    scope.registerLazySingleton<Repository>(const _RepositoryFactory());
  }
}

typedef CobaltRoot = $CobaltRootScope;

const String $cobaltRootScopeName = 'app';

Future<CobaltScope> $startCobalt() => CobaltApplication.start(
  root: const $CobaltRootScope(),
  rootName: $cobaltRootScopeName,
);
```

```dart
final scope = await $startCobalt();
```

`CobaltRoot`는 `$` 없는 이름의 같은 클래스이므로, 빠른 시작의 `const CobaltRoot()`와
`const $CobaltRootScope()`는 서로 바꿔 쓸 수 있습니다.

여기서는 읽기 쉽도록 생략했지만, 실제 파일은 import한 모든 이름 앞에 그 URL의 해시에서 만든 별칭을 붙입니다.
`_i178.CobaltFactory` 같은 식입니다. 카운터가 아니라 해시인 이유는 import 하나를 추가했을 때 다른 모든 번호가
바뀌어 한 줄짜리 변경이 파일 전체의 diff가 되지 않도록 하기 위해서입니다.

이 출력에는 의도된 점이 네 가지 있습니다:

- **클로저가 아니라 private const 팩토리 클래스.** `const` 팩토리는 캡처된 상태를 갖지 않으므로, 두 번째 시작이
  첫 번째 그래프의 객체를 재사용할 수 없습니다.
- **위상 정렬 순서의 등록**, 빌드 시점에 계산됩니다. 프로퍼티 주입 필드도 간선으로 세므로, bloc은 언제나 자신이
  주입받는 것보다 뒤에 등록됩니다.
- **리플렉션도, 런타임 스캔도 없습니다.** 그 파일에 있는 것이 그래프의 전부입니다.
- **`$cobaltBootstrap`은 getter입니다.** 저장된 리스트가 아니므로 재시작하면 새 단계를 받습니다.
  [§11](#11-앱이-시작되기-전에-끝나야-하는-작업)을 참고하십시오.

제너레이터는 여러분의 포맷 검사가 쓰는 것과 같은 `dart_style`로 출력을 포맷하므로, 둘이 어긋나는 일은
없습니다.

---

## 4. 프로퍼티 주입

협력 객체가 다섯 개인 클래스라고 해서 생성자 파라미터가 다섯 개 필요한 것은 아닙니다. 필드를 선언하고,
제너레이터가 그 옆에 작성하는 믹스인을 섞으십시오:

```dart
part 'counter_bloc.g.dart';

@cobaltTransient
class CounterBloc with _$CounterBloc {
  CounterBloc();

  @injected
  late final Repository _repository;

  @injected
  late final Telemetry _telemetry;

  void increment() => _telemetry.record('${_repository.hashCode}');
}
```

이것이 마법이 아니라 안전한 방식인 이유는 세 가지입니다:

- 필드는 `late final`이므로 **한 번만 쓸 수 있습니다**. 두 번 할당하면 `LateError`를 던집니다.
- 필드는 **private**이어도 됩니다. 생성된 믹스인은 같은 라이브러리의 `part`이므로 이를 볼 수 있습니다.
- 필드는 다른 것과 마찬가지로 **의존성 간선**이므로, 순서 결정과 완전성 검사가 모두 이를
  포함합니다.

`part` 지시문과 `with _$ClassName`은 여러분이 작성합니다. 믹스인을 빠뜨리면 `cobalt_missing_injection_mixin`이
에디터에서 알려 주고, 컨테이너가 등록하지 않는 클래스에 `@injected`를 붙이면 대신
`cobalt_injected_field_needs_an_injectable`이 알려 줍니다. 두 실수는 고치는 방법이 다르기
때문입니다. 앞의 규칙의 빠른 수정은 `part` 지시문이 없으면 그것도 함께 써 줍니다.

---

## 5. 그래프는 완전해야 합니다

빌드 단계는 바로 이것을 위해 있습니다. 아무것도 등록하지 않은 의존성은 빌드를 실패시키며, 다시 빌드할 때마다
하나씩이 아니라 빠진 것을 한 번에 모두 알려 줍니다:

```
The graph is missing 2 registrations.
  CatalogService requires Repository<User>
  ApiGateway requires HttpClient in dev, test
Annotate the classes that provide them with @CobaltInject, or name them in
@CobaltScopeRoot(provides: [...]) when something outside the generated container
registers them.
```

의존성으로 세는 것은 모두입니다. 생성자 파라미터, `@injected` 필드, 그리고 `@CobaltInit(dependsOn:)`입니다.
`@Named` 한정자는 키의 일부이므로, 이름 없는 `Logger`만 있는 곳에서 `@Named('audit')
Logger`를 요청하면 빠진 것이 됩니다. 각 환경은 따로 검사되므로, `dev` 전용 등록으로는 `prod`에서도 실행되는,
그것에 의존하는 쪽을 충족할 수 없습니다.

다음도 빌드 시점에 거부됩니다. 같은 키의 중복 등록, 의존성 순환(그 순환을 지목합니다), 한 패키지 안의
`@CobaltScopeRoot` 클래스 두 개, 추상 클래스나 public 생성(generative) 생성자가 없는 클래스의 `@CobaltInject`입니다.

**제네릭 클래스**는 등록할 인스턴스화를 직접 나열하고, 인스턴스화마다 등록이 하나씩 생깁니다.

```dart
@CobaltInject(instantiations: [Cache<Note>, Cache<User>])
class Cache<T> {
  Cache(this.store);
  final Store<T> store;
}
```

이렇게 하면 `Cache<Note>`와 `Cache<User>`가 등록되고, 각각 자기 `Store<Note>` 또는 `Store<User>`로 만들어집니다.
`name`, `lifetime`, `dispose`와 환경은 그 각각에 모두 적용됩니다. `instantiations` 없는 제네릭 클래스는
어떤 인스턴스화를 등록할지 알려 주는 것이 없으므로 빌드 오류입니다. 각 항목에는 모든 타입 인자를 명시해야 하고
(타입 인자 없는 `Cache`는 `Cache<dynamic>`으로 읽혀 거부됩니다). `exposeAs`는 타입 인자 없이 씁니다.
`Cache<T> implements Store<T>`에 `exposeAs: Store`를 쓰면 각 인스턴스화가 자기 `Store<Note>`, `Store<User>`로
등록됩니다.

`@injected` 필드도 같은 방식으로 동작합니다. 클래스는 생성된 믹스인을 자신의 타입 매개변수와 함께 섞고,
각 인스턴스화는 자기 타입 인자로 필드를 읽습니다.

```dart
@CobaltInject(instantiations: [Cache<Note>, Cache<User>])
class Cache<T> with _$Cache<T> {
  Cache();

  @injected
  late final Store<T> store;
}
```

`Cache<User>`는 `Store<User>`를 읽고, `Store<User>`를 등록하는 것이 없으면 `Cache<User>`에 대해서만 빌드가
실패합니다.

그 밖의 곳에서는 제네릭이 문제없습니다. `Repository<User>`와 `Repository<Order>`는 별개의 등록 두 개인데,
`CobaltKey`가 `Type`으로 만들어지고 이 둘은 서로 다른 타입이기 때문입니다.

그 경계는 솔직하게 밝혀 둘 만합니다. 이 검사가 다루는 것은 제너레이터가 생성한 것입니다. 직접 작성한 팩토리는
`create` 안에서 해석하므로, 그것이 무엇을 요청할지는 정적으로 알 수 없습니다. 그런 경우에는 `cobalt_test`의
`expectGraphResolves`가 검사 수단입니다. [§18](#18-테스트)을 참고하십시오.

---

**컨테이너 주위에 조합한 직접 작성한 등록도 같은 규칙을 따릅니다.** 지연 등록은 `$CobaltRootScope().build(scope)`보다
위에 있어도 제너레이터가 등록한 것을 해석할 수 있지만, 즉시 생성 등록은 그럴 수 없으며 오류가 그렇게 알려 줍니다.
빠진 타입을 지목하고, 스코프가 아직 빌드되는 중이라는 점을 덧붙입니다.

## 6. 생성된 루트 위에 조합하기

제너레이터는 자기 패키지의 어노테이션만 봅니다. 그 밖의 것(`--dart-define`에서 오는 값, 스코프 자체가 필요한
객체, 다른 패키지의 프로바이더)은 생성된 빌더를 감싸는 빌더에
넣습니다:

```dart
class NotesScope implements CobaltScopeBuilder {
  const NotesScope(this.environment);

  final CobaltEnvironment environment;

  @override
  void build(CobaltScope scope) {
    $CobaltRootScope(environment: environment).build(scope);
    scope
      ..registerSingleton<CobaltEnvironment>(environment)
      ..registerSingleton<SessionManager>(SessionManager(scope));
  }
}
```

`$startCobalt()`가 반환된 뒤에 등록하는 대신 감싸기 때문에 이것들이 1단계 안에 머뭅니다. 그래프가 이미 올라온
뒤에 덧붙는 것이 아니라, 비동기 초기화가 실행되기 전에 등록됩니다.

이제 완전성 검사에 이것들을 알려 주십시오. 그렇지 않으면 빠진 것으로 보고합니다:

```dart
@CobaltScopeRoot(name: 'app', provides: [SessionManager, CobaltEnvironment])
class AppScope {
  const AppScope();
}
```

약속은 아무것도 등록하지 않습니다. 다른 무언가가 등록할 것이라고 말할 뿐입니다. `CobaltProvided(Logger, name: 'audit')`는
이름 있는 등록을 약속합니다. 약속해 놓고 등록하지 않으면 다시 런타임 실패로 돌아갑니다. 이 리스트는 제너레이터가
검증할 수 있는 것이 아니라 여러분이 하는 진술입니다.

---

## 7. Flutter 앱 시작하기

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
      root: const NotesScope(notesEnvironment),
      bootstrap: () => $cobaltBootstrap(notesEnvironment),
      rootName: $cobaltRootScopeName,
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: (context, error, retry) => StartupFailed(error: error, retry: retry),
    ),
    home: const HomeScreen(),
  ),
);
```

`bootstrap`이 리스트가 아니라 함수인 것은 의도적이며, 제너레이터가 `$cobaltBootstrap`을 getter로 내보내는 것도
같은 이유입니다. 단계는 리소스를 보유하며, 재시작하면 새 단계를 받아야 합니다.

`CobaltAppScope.of(context).restart()`는 그래프를 다시 빌드합니다. 실패한 시작을 재시도하는 것도 같은 호출입니다.

Flutter 밖에서는 `await $startCobalt()`가 전부입니다.

`$startCobalt(initTimeout: ...)`는 1단계에 시간 제한을 둡니다. 시간이 지나면 시작은 아직 빌드되지 않은 것을
지목하는 `CobaltInitTimeoutError`로 실패합니다. 자세한 내용은 Manual Mode 가이드의 8절에 있습니다.

---

## 8. 위젯에서 그래프 읽기

```dart
final repository = context.cobalt<Repository>();
final formatters = context.cobaltAll<NoteFormatter>();
final editor = context.cobaltWithParam<NoteEditor, $NoteEditorArgs>((id: 7, draft: true));
final scope = context.cobaltScope;
```

각각은 위젯 위의 **가장 가까운** 스코프에서 해석하고 거기서부터 위로 올라가므로, 플로우나 세션 스코프의
등록은 그 안의 모든 것에 대해 루트의 등록을 섀도잉합니다.

문제를 겪기 전에 알아 둘 것이 하나 있습니다. `Navigator.push`는 새 라우트를 push한 위젯이 아니라
내비게이터의 context에서 빌드합니다. 제자리에 마운트되었을 때는 잘 해석되던 화면도, 읽던 프로바이더가
push하는 화면 *안에* 있다면 같은 위젯을 push했을 때 `CobaltNoScopeError`를 던집니다. 그런 경우에는 스코프를
명시적으로 넘기거나, 프로바이더 아래에서 push하십시오.

---

## 9. 앱보다 먼저 끝나는 스코프

제너레이터가 작성하는 것은 **루트**입니다. 앱보다 수명이 짧은 스코프(세션, 플로우, 화면)는 여러분이 작성하는
`CobaltScopeBuilder`이며, 생성된 파일이 쓰는 것과 같은 공개 API로 등록합니다. 이것은 제너레이터의 빈틈이
아닙니다. 세션 스코프에 무엇이 들어갈지는 수명에 관한 결정이며, 어노테이션의 어떤 것도 세션이 언제 끝나는지
말해 주지 않습니다.

### 세션

```dart
class SessionManager {
  SessionManager(this._root);

  final CobaltScope _root;
  CobaltScope? _session;

  Future<void> signIn(User user) async {
    _session = _root.push('session:${user.id}')
      ..registerLazySingleton<Draft>(const DraftFactory());
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

### 화면

```dart
CobaltScopeWidget(
  name: 'counter-screen',
  builder: const ScreenScope(),
  child: const Counter(),
)
```

위젯이 마운트될 때 생성되고, 언마운트될 때 해제됩니다. 스코프는 `init()`이 완료된 뒤에야 게시되므로,
완전히 동기적인 그래프도 `loading` 프레임을 한 번 렌더링합니다.

`@cobaltTransient`가 제 몫을 하는 곳이 바로 여기입니다. 트랜지언트는 해석할 때마다 다시 빌드되고 아무도
보유하지 않으므로, 자기만의 스코프를 주어야 수명과 해제 시점이 생깁니다.

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
```

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

## 10. 등록한 것 닫기

스코프는 보유한 것을 **생성** 순서의 역순으로 해제합니다. 선언 순서가 아닙니다. 직접 작성한 컨테이너의 버그가
바로 여기에 있습니다. Dart에는 구조적 타이핑이 없으므로, 이름이 맞는 `dispose()` 메서드만으로는 충분하지
않습니다:

```dart
@cobaltInject
class Cache implements Disposable {
  @override
  void dispose() { ... }
}

@cobaltInit
class Database implements AsyncInitializable, AsyncDisposable {
  @override
  Future<void> init() async { ... }

  @override
  Future<void> dispose() async { ... }
}
```

바꿀 수 없는 타입(SDK의 타입, 다른 패키지의 타입, base 클래스 뒤에 있는 타입)이라면 어노테이션에서 해제 방법을
지정하십시오. 어노테이션 인자는 상수여야 하므로 최상위 함수를
받습니다:

```dart
Future<void> closeClient(http.Client client) => client.close();

@CobaltInject(dispose: closeClient)
class ApiClientHolder { ... }
```

`dispose:`는 스코프가 보유하는 등록에서만 의미가 있습니다. `@cobaltTransient`나 `@CobaltParam`이 있는 클래스에서는
영영 실행되지 않는 콜백이 되는 대신 빌드 오류가 됩니다. 트랜지언트는 스코프가 닫을 대상이 아니기
때문입니다.

### 닫을 수 있어 보이지만 그렇지 않은 Flutter 타입

`ChangeNotifier.dispose`는 `Disposable.dispose`와 정확히 일치하지만, 그래도 스코프에는 보이지 않습니다.
명시하십시오:

```dart
@cobaltInject
class Filters extends ChangeNotifier implements Disposable {}
```

bloc에는 `cobalt_bloc`이 한 줄로 해결해 줍니다:

```dart
@cobaltInject
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);
}
```

또는 믹스인을 쓸 수 없는 곳이라면 `@CobaltInject(dispose: closeBloc)`을 씁니다.

그리고 위젯 트리에는 `BlocProvider(create:)`가 아니라 반드시 `BlocProvider.value`로 넘기십시오. 전자는
언마운트될 때 넘겨받은 것을 닫아 버리지만, 스코프는 여전히 그것을 보유하고 있어 다음 해석 때 죽은 객체를
내주게 됩니다.

`cobalt_registration_is_never_released`가 이 모든 것을 에디터에서 잡아냅니다. 스코프가 볼 수 없는 `dispose()`
또는 `close()`를 가진 등록된 클래스입니다.

### 해제가 잘못되었을 때

해제는 설계상 최선을 다하는(best-effort) 방식입니다. 예외를 던진 단계는 기록되고 나머지는 계속 실행되며,
트리 전체가 기한 하나를 공유하고, 스코프는 언제나 `disposed`에 도달합니다. 끝나지 않은 것은 첫 번째 실패가
나머지 아홉을 가리는 대신 `CobaltDisposeError`(`failures`, `timeouts`, `hasTimeout`)에
나열됩니다.

`adopt`는 객체를 의존성으로 만들지 않고 스코프의 수명에 묶습니다:

```dart
scope.adopt(subscription, dispose: (it) => it.cancel());
```

---

## 11. 앱이 시작되기 전에 끝나야 하는 작업

서로 다른 질문에 답하는 두 단계가 있습니다.

**0단계: `@CobaltBootstrap`.** 컨테이너가 생기기 전입니다. 플랫폼 바인딩, 원격 설정 등 그래프 자체에 필요한
모든 것입니다. 단계는 엄격하게 순서대로 실행되며(출력이 안정되도록 먼저 `order`, 그다음 이름 순), 아무것도
주입받을 수 없습니다. 아직 주입해 줄 곳이 없기 때문입니다. 생성자가 필수 파라미터를 받는 부트스트랩 단계는
빌드 오류이며, 그보다 먼저 `cobalt_bootstrap_step_cannot_inject`가 알려 줍니다.

```dart
@CobaltBootstrap(order: 0)
class BindPlatform implements CobaltBootstrapStep {
  const BindPlatform();

  @override
  String get name => 'bind-platform';

  @override
  Future<void> run() async => WidgetsFlutterBinding.ensureInitialized();
}
```

실행이 끝나면 루트 스코프가 단계들을 `adopt`하므로, 무언가를 연 단계는 해제 시 그것이 닫힙니다. 그 위에
빌드된 모든 것이 닫힌 뒤 마지막으로 닫힙니다. 단계가 실패하면 이미 실행된 단계들은 오류가 다시 던져지기
전에 역순으로 해제됩니다.

**1단계: `@CobaltInit`.** 컨테이너 안에서입니다. 비동기 싱글턴이며, 의존성 순서대로 빌드됩니다.

```dart
@CobaltInit(dependsOn: [Database])
class SearchIndex implements AsyncInitializable {
  SearchIndex(this._database);

  final Database _database;
  final _terms = <String>[];

  @override
  Future<void> init() async => _terms.addAll(await _database.terms());
}
```

`AsyncInitializable`은 이 어노테이션이 전제하는 인터페이스입니다. 필수인 것은 `init()` *메서드*뿐이지만(파서와
린트 규칙 모두 이름으로 찾습니다), 인터페이스를 선언해야 읽는 사람에게 계약이 보이며, `init()`이 없다는 모든
오류 메시지가 하라고 안내하는 것도
이것입니다.

생성된 팩토리는 객체를 생성하고 `init()`을 기다린 뒤, `dependsOn`을 `CobaltKey`로 옮겨 비동기 싱글턴으로
등록합니다. 같은 계층의 독립된 초기화는 `Future.wait`로 함께 실행되며, 실제로 의존하는 것만 기다립니다.

`dependsOn`은 주입이 아니라 순서를 정하는 간선입니다. 의존성은 평소처럼 생성자에서 받습니다. 등록되어 있지만
비동기가 **아닌** 키를 지정하면 겉보기처럼 조용히 아무 일도 하지 않는 것이 아니라 빌드 오류입니다. 기다릴
빌드가 없기 때문입니다.

`CobaltApplication.start`는 두 단계가 모두 끝나야 반환하므로, 호출할 `allReady()`도, 따져 봐야 할
"등록되었지만 준비되지 않은" 상태도 없습니다.

### 처음 요청될 때 빌드

1단계는 시작할 때 모든 것을 빌드합니다. 앱과 수명이 같지만 필요로 하는 화면은 적은, 비용이 큰 객체라면
지연으로 표시하십시오. 그러면 첫 `getAsync`까지 아무것도 빌드되지 않습니다:

```dart
@CobaltInit(lazy: true)   // 또는 @cobaltLazyInit
class SearchEngine implements AsyncInitializable {
  SearchEngine(this._index, this._clock);

  final Model _index;     // 이것도 지연 등록이며, 생성된 팩토리가 기다립니다
  final Clock _clock;     // 일반 등록이며, 평소처럼 읽습니다

  @override
  Future<void> init() async => _index.warmUp();
}
```

`Future`를 반환하는 모듈 멤버에서는 같은 것이 `@CobaltInject(lazyInit: true)`입니다.

제너레이터는 이를 `registerLazyAsyncSingleton`으로 등록하며, 그 팩토리는 마찬가지로 지연인 모든 의존성을
`getAsync`로 기다립니다. 세 가지는 빌드 오류입니다. 그렇지 않으면 각각 기기에서 실패할 것이기
때문입니다:

- 지연 등록을 주입받는 동기 클래스나 즉시 생성 비동기 클래스. 누군가 기다리기 전까지는 건네줄 것이 없습니다.
  의존하는 쪽도 지연으로 만들거나, 필요한 곳에서 `getAsync`로 해석하십시오.
- 어떤 클래스에서든 지연 타입의 `@injected` 필드. 필드는 동기로 채워집니다.
- 지연 등록을 가리키거나 지연 등록에 선언된 `dependsOn`. `dependsOn`은 `init()`의 순서를 정하는데, 지연 등록은
  `init()`이 빌드하지 않습니다.

런타임에는 Manual Mode 가이드에서 설명한 대로 동작합니다. 동시에 들어온 호출은 빌드 하나를 공유하고, 실패한
빌드는 다음 호출이 다시 시도하며, 첫 `getAsync` 전의 `get`은 `CobaltLazyAsyncError`를 던지고, 해제는 진행 중인
빌드를 기다립니다. 위젯에서는 `CobaltAsyncBuilder<SearchEngine>`가 첫 화면이 빌드하는 동안 `loading`을 보여
주고, 그 이후의 모든 화면에서는 바로 렌더링합니다.


화면이 열리기 전에 준비해 두려면 워밍업하십시오. `CobaltAppScope(warmUp: [CobaltKey(SearchEngine)])`는 그래프가
올라오자마자 `loading`을 붙잡아 두지 않고 앱이 표시되는 동안 뒤에서 빌드를 시작하며, 다른 곳에서는
`scope.warmUp([...])`가 같은 일을 합니다. 그사이에 요청한 화면은 두 번째 빌드를 시작하지 않고 그것을 기다리며,
실패는 `CobaltWarmUpError` 하나로 함께 전달됩니다.


### 호출할 때마다 새로 빌드

트랜지언트 `@CobaltInit` 클래스는 `getAsync`할 때마다 빌드됩니다. 호출할 때마다 생성하고 `init()`을 기다린 뒤
넘겨줍니다. 스코프는 그중 어느 것도 보유하지 않습니다.

```dart
@cobaltTransient
@cobaltInit
class Report implements AsyncInitializable {
  Report(this._service);

  final ReportService _service;

  @override
  Future<void> init() => _service.assemble(this);
}

final report = await scope.getAsync<Report>();
```

`Future`를 반환하는 모듈 멤버에서는 같은 것이 `@cobaltTransient`입니다. 제너레이터는 이를 `registerAsyncFactory`로
등록하며, 그 팩토리는 모든 지연 의존성을 `getAsync`로 기다립니다. 지연 등록과 같은 세 가지(이를 주입받는 동기
클래스나 즉시 생성 비동기 클래스, 그 타입의 `@injected` 필드, 이를 지정하는 `dependsOn`)가 빌드 오류이며, 클래스
자체에 대해서도 두 가지가 더 있습니다. 지연 등록은 공유되는 인스턴스 하나이므로 `lazy: true`, 그리고 `init()`이
빌드하지 않으므로 `dependsOn`입니다. `dispose:`는 다른 트랜지언트와 마찬가지로 거부됩니다.

---

## 12. 호출하는 쪽에서 오는 값

객체의 절반은 그래프에서, 나머지 절반은 그것을 빌드하는 쪽에서 옵니다. 컨테이너가 알 수 없는 절반에
표시하십시오:

```dart
@cobaltInject
class Greeting {
  Greeting(this._config, {@cobaltParam required this.name, @cobaltParam required this.loud});

  final Config _config;
  final String name;
  final bool loud;
}
```

**표시한 파라미터는 컨테이너가 빌드할 수 있는 경우에도 언제나 호출하는 쪽에서 옵니다.**
`@cobaltParam Draft draft`는 `Draft`가 등록되어 있든 아니든 `Draft`를 레코드에 넣으며, 완전성 검사는 더 이상
이를 요구하지 않습니다. 표시한다는 것은 그런 뜻이며, 그래프에 이미 있는 것을 표시해도 진단은 없습니다. 그러니
값이 더 이상 들어오지 않는다면 등록을 보기 전에 여기를 먼저
확인하십시오.

제너레이터는 인자 타입을 컨테이너 옆에 이름 있는 레코드로 작성하고, 파라미터가 있는 팩토리를
등록합니다:

```dart
// typedef $GreetingArgs = ({String name, bool loud});
final greeting = context.cobaltWithParam<Greeting, $GreetingArgs>((name: 'Cobalt', loud: false));
```

인자가 하나뿐이어도 위치 기반이 아니라 이름 있는 레코드입니다. 두 번째 인자를 추가해도 바뀌는 것은 타입의
내용이지, 타입의 이름이나 호출의 형태가 아닙니다.

제너레이터가 강제하는 규칙은 두 가지입니다:

- 표시한 파라미터는 완전성 검사와 순서 결정에서 **제외됩니다**. `String`을 등록하는 것은 없으며, 등록하려 해서도
  안 됩니다.
- 표시한 파라미터는 **필수이거나 nullable**이어야 합니다. 레코드에는 기본값이 없으므로, `@cobaltParam this.draft = false`는
  호출하는 쪽에 `draft`를 넘길 의무를 남기고, 주어진 기본값은 쓸모없게 됩니다. 이는 뜻밖의 동작이 아니라
  빌드 오류입니다.

이를 그냥 `get<T>()`로 해석하면 `CobaltParamRequiredError`를 던지고, 잘못된 타입을 넘기면 키와 두 타입을
지목하는 `CobaltParamTypeError`를 던집니다.


### 비동기로 빌드

`@CobaltInit` 클래스에서는 빌드가 비동기입니다. 호출할 때마다 생성하고 `init()`을 기다린 뒤
넘겨줍니다:

```dart
@cobaltInit
class Document implements AsyncInitializable {
  Document(this._store, {@cobaltParam required this.id});

  final DocumentStore _store;
  final int id;

  @override
  Future<void> init() => _store.load(this);
}

// typedef $DocumentArgs = ({int id});
final document = await scope.getAsyncWithParam<Document, $DocumentArgs>((id: 42));
```

제너레이터는 `CobaltAsyncParamFactory`를 내보내고 `registerAsyncParamFactory`로 등록합니다. 호출마다 빌드되며
1단계에서 빌드되는 일은 없으므로, 빌드는 이런 클래스의 `lazy: true`와 `dependsOn`, 그리고 이를 지정하는
`dependsOn`을 거부합니다. 그 팩토리는 모든 지연 의존성을 `getAsync`로 기다립니다.

---

## 13. 선택적 의존성

타입에 붙인 `?`가 표기의 전부입니다. 어노테이션은 없습니다. `?`가 없으면 어차피 필드가 null을 담을 수 없기
때문입니다:

```dart
@cobaltInject
class Reporter {
  Reporter(this.clock, this.telemetry);

  final Clock clock;
  final Telemetry? telemetry;
}

@cobaltInject
class Dashboard with _$Dashboard {
  Dashboard();

  @injected
  late final Telemetry? _telemetry;
}
```

둘 다 `getOrNull`로 해석되므로, `Telemetry`를 등록하지 않은 그래프는 빌드를 실패시키는 대신 null을
주입합니다.

nullable 여부는 등록 **키**의 일부가 아니며(`Foo?`도 `Foo` 등록을 읽습니다), 선택적 의존성도 무언가가 실제로
등록하면 여전히 순서를 정하는 간선입니다. `getOrNull`은 "아무것도 등록되어 있지 않음"일 때만 null을 반환합니다.
`init()` 전에 요청한 비동기 싱글턴은 여전히 예외를 던집니다. "준비되지 않음"과 "존재하지 않음"은 서로 다른
사실이기 때문입니다.

**기본값**은 생성자 매개변수를 선택적으로 만드는 또 다른 방법입니다. 그래프에서 그 타입을 등록하는 것이
없으면 제너레이터가 호출에서 그 매개변수를 빼고 기본값이 적용됩니다. 등록하는 것이 있으면 다른 의존성처럼
주입됩니다:

```dart
@cobaltInject
class Api {
  Api(this.client, {this.retries = 3});

  final HttpClient client;
  final int retries;
}
```

`int`를 등록하는 것이 없으므로 `retries`는 3을 받습니다. 위치 매개변수는 끝에서부터만 뺄 수 있습니다.
기본값이 있는 위치 매개변수 뒤에 주입되는 매개변수가 있으면 여전히 빌드 오류이며, 오류 메시지가 이름 있는
매개변수로 바꾸라고 알려 줍니다.

---

## 14. 직접 작성하지 않은 타입

`@CobaltInject`는 클래스에 붙으므로, 여러분이 소유한 클래스에만 닿습니다. 그 밖의 모든 것(다른 패키지의
클라이언트, SDK가 건네는 값)을 들여오는 방법은 모듈입니다:

```dart
Future<void> closeClient(http.Client client) => client.close();

@cobaltModule
class NetworkModule {
  const NetworkModule();

  @cobaltInject
  Dio dio(AppConfig config) => Dio(BaseOptions(baseUrl: config.apiBase));

  @CobaltInject(dispose: closeClient)
  http.Client client() => http.Client();

  @cobaltSingleton
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
```

클래스에 붙인 어노테이션은 아무 설정도 담지 않습니다. 각 멤버가 클래스와 같은 어노테이션(수명, `name`,
`exposeAs`, `dispose`, 환경)으로 자기 등록을 구성하며, 멤버의 파라미터는 생성자 파라미터처럼
해석됩니다.

규칙과 각각의 이유입니다:

- 클래스에는 **인자를 받지 않는 public `const` 생성자**가 있어야 합니다. 그래야 내보낸 팩토리가
  `const NetworkModule()`을 보유하고 상태를 갖지 않습니다.
- **`Future<T>`를 반환하는 것이 유일한 비동기 신호입니다.** 그런 멤버는 비동기 싱글턴이 되며, 비동기 멤버
  사이의 순서는 직접 작성하는 것이 아니라 제너레이터가 계산합니다.
- 멤버는 **추상일 수 없습니다.** 클래스를 그 자신의 생성자로 빌드하는 것은 `@CobaltInject`가 이미 뜻하는
  바이며, 그것을 말하는 두 번째 방법은 없습니다.
- 멤버에는 `@CobaltParam`을 쓸 수 **없습니다**. 모듈은 여러분이 작성하지 않은 타입을 등록합니다. 호출하는
  쪽에서 오는 값은 여러분이 작성한 클래스에 속합니다.

멤버는 클래스가 참여하는 모든 것에 참여합니다. 중복 검출, 위상 정렬, 완전성
검사입니다.

### 등록 감싸기

`@CobaltDecorates`는 등록이 내주는 객체를 그 클래스를 건드리지 않고 감쌉니다. 로그, 재시도, 캐시, 다른 패키지의
클라이언트를 둘러싼 메트릭 등입니다:

```dart
@CobaltDecorates(ApiClient)
class LoggingApi implements ApiClient {
  LoggingApi(this._inner, this._log);

  final ApiClient _inner;
  final Logger _log;
}
```

이 클래스는 등록되지 않습니다. 제너레이터는 그것을 감싸는 `CobaltDecorator`와 `build()` 안의
`scope.decorate<ApiClient>(...)`를 내보내므로, 주입되는 필드를 포함한 모든 `get<ApiClient>()`가 래퍼를 받습니다.
`examples/codegen_basics`에는 `Repository`에 적용된 데코레이터가 하나 있습니다.

규칙과 각각의 이유입니다:

- 클래스는 **대상을 구현하며**, 그 타입의 생성자 파라미터를 **정확히 하나** 받습니다. 그것이 감쌀 인스턴스입니다.
  그 밖의 모든 파라미터는 등록을 소유한 스코프에서 해석되며, `@Named`도 마찬가지입니다. `@CobaltParam`은
  거부됩니다. 데코레이터를 적용하는 것은 스코프이고, 호출하는 쪽이 없기 때문입니다.
- **`@injected` 필드**는 다른 클래스와 마찬가지로 동작합니다. 생성된 `_$ClassName`을 섞으면, 생성된 데코레이터가
  생성 직후 같은 리졸버에서 필드를 채웁니다. 이 필드는 아래의 모든 검사에서 데코레이터의 의존성으로
  셉니다.
- 한 등록에 데코레이터가 두 개라면 **`order:`가 필요합니다**. 낮은 쪽이 안쪽입니다. 빌드는 추측하지 않으며, 같은
  order 두 개도 거부합니다. 환경이 결코 겹치지 않는 데코레이터끼리는
  경쟁하지 않습니다.
- 대상은 **데코레이터가 활성화된 모든 곳에서 등록되어 있거나**, `provides:`에 지정되어 있어야 합니다. 데코레이터의
  의존성은 다른 클래스와 마찬가지로 완전성 검사를 거치며, 자기 대상에 의존하는 무언가를 필요로 하는 데코레이터는
  순환입니다.
- 데코레이터는 **지연 비동기 등록을 받을 수 없습니다**. 인스턴스를 내줄 때 동기로 실행되기 때문입니다. 지연
  등록을 감싸는 것은 괜찮습니다.
- 1단계가 실행되는 동안 데코레이터가 적용된 등록을 해석하는 비동기 클래스는 **데코레이터가 해석하는 것을
  기다립니다**. 제너레이터는 이를 대상이 아니라 소비자의 `dependsOn`에 추가하므로, 대상을 재정의해도 이 대기는
  유지됩니다.

런타임에는 Manual Mode와 같은 `decorate`입니다. 보유되는 등록에는 한 번 데코레이터가 적용되어 공유되고,
재정의에도 그것이 대체한 등록과 똑같이 데코레이터가 적용되며, 스코프가 닫는 것은 안쪽 인스턴스이지
데코레이터가 아닙니다.

`@CobaltDecorates(ApiClient, allNames: true)`는 이름이 있든 없든 **그 타입의 모든 등록**을 감싸며,
`scope.decorateAll<ApiClient>(...)`가 됩니다. `name:`과 함께 쓸 수 없고, 활성화된 모든 곳에 그 타입의 등록이
하나 이상 있어야 하며, 자신이 감싸는 각 등록의 데코레이터들과 `order:`를 두고
경쟁합니다.


**훅.** `CobaltHook<T>`를 상속하는 클래스에 `@cobaltHookAll`을 붙이면 생성된 루트 스코프에 추가됩니다. 모든
등록보다 앞에 내보내지는 `scope.hookAll<T>(...)`이므로, 즉시 생성 등록도 이미 이 훅을 거칩니다. 훅은 어느 등록이
빌드했든 그래프가 빌드하는 모든 `T`에서 실행되며, 그것을 바꿀 수는 없습니다(데코레이터가 왜 이 일을 할 수
없는지는 Manual Mode 가이드의 3절을 참고하십시오). 클래스에는 필수 파라미터가 없는 생성자가 있어야 합니다. 훅은
무엇이든 빌드되기 전에 추가되므로 아직 주입할 것이 없으며, 필요한 것은 `onBuilt`가 받는 `resolver`에서
해석합니다. 여러 개라면 `order:`, 그다음 클래스 이름 순으로 추가되며, `@CobaltEnvironment`는 다른 등록과 마찬가지로
훅 하나를 제한합니다.

```dart
@cobaltHookAll
final class JoinRegistry extends CobaltHook<Loggable> {
  const JoinRegistry();

  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) =>
      resolver.get<LogRegistry>().add(instance);
}
```

---

## 15. 그래프 하나, 여러 빌드

한 빌드가 다른 빌드와 정말로 다른 구현을 필요로 하기 전까지는 이 절을 건너뛰십시오. `@CobaltEnvironment`를
한 번도 쓰지 않는 프로젝트에는 그래프가 하나뿐이고, 모든 등록이 그 그래프에 속하며, `$startCobalt()`는 인자를
전혀 받지 않습니다.

```dart
@CobaltInject(exposeAs: ApiClient)
@CobaltEnvironment.prod
@CobaltEnvironment.stage
class LiveApiClient implements ApiClient { ... }

@CobaltInject(exposeAs: ApiClient)
@CobaltEnvironment.dev
@CobaltEnvironment.test
class FakeApiClient implements ApiClient { ... }
```

```dart
final scope = await $startCobalt(environment: CobaltEnvironment.prod);
```

어노테이션은 리스트를 받는 대신 반복합니다. 등록은 환경의 *집합*에 속하지만, 시작할 때는 정확히 *하나*를 고르기
때문입니다. `dev`, `stage`, `prod`, `test`는 상수일 뿐 닫힌 집합이 아닙니다. `@CobaltEnvironment('canary')`도
똑같이 동작합니다.

생성된 컨테이너는 그 선택을 필드로 받고, 제한된 등록만 조건으로 감쌉니다. 여러분이 직접 작성했을 코드와
정확히 같습니다:

```dart
if (environment.matches(const <String>{'dev', 'test'})) {
  scope.registerLazySingleton<ApiClient>(const _FakeApiClientFactory());
}
```

여기서 세 가지가 따라 나옵니다:

- **끝까지 선택 사항으로 남습니다.** 파라미터는 무언가가 환경을 지정할 때만 나타나며, 그때에도 기본값은
  `CobaltEnvironment.defaultEnvironment`, 즉 나뉘지 않은 그래프가 속한 단 하나의 환경입니다. 이 기본값은 제한이
  없는 등록에만 일치하므로, 나뉜 그래프를 환경을 고르지 않고 시작하면 나뉜 타입은 등록되지 않은 채 남고, 엉뚱한
  클래스를 조용히 돌려주는 대신 첫 해석이 그 사실을 알리며
  실패합니다.
- **아무것도 두 번 등록되지 않습니다.** 환경이 겹치는 같은 키의 등록 두 개는 둘 다 지목하며 빌드를
  실패시킵니다. 하나가 환경을 전혀 지정하지 않은 경우도 포함됩니다. 제한이 없는 등록은 모든 곳에 존재하기
  때문입니다.
- **완전성은 환경별로 검사되므로**, `dev` 전용 등록으로는 `prod`에서도 실행되는, 그것에 의존하는 쪽을 충족할 수
  없습니다.

부트스트랩 단계도 환경을 받습니다. 그중 하나라도 환경을 받으면 `$cobaltBootstrap`은 선택한 환경을 받는 함수가
되며, 건너뛴 단계는 실행되지도 `adopt`되지도 않습니다.

`cobalt_environment_needs_a_registration`은 `@CobaltEnvironment`가 아무것도 등록하지 않는 클래스에 붙어 조용히
아무 일도 하지 않는 경우를 잡아냅니다.

---

## 16. 린트 플러그인

제너레이터가 쓰는 것과 같은 파싱 계층 위에 만든 규칙 열여덟 개이므로, 실수가 `build_runner`를 실행할 때만이
아니라 에디터에서 바로 드러납니다.

```yaml
# analysis_options.yaml
plugins:
  cobalt_lint: ^1.0.0
```

| 규칙 | 잡아내는 것 |
|---|---|
| `cobalt_missing_injection_mixin` | 컨테이너가 등록하거나 데코레이터로 적용하는 클래스에서 `with _$ClassName` 없이 쓴 `@injected` 필드 |
| `cobalt_injected_field_needs_an_injectable` | 컨테이너가 등록하지도, 데코레이터로 적용하지도 않는 클래스의 `@injected` 필드 |
| `cobalt_param_needs_an_injectable` | 컨테이너가 등록하지 않는 클래스의 `@CobaltParam` |
| `cobalt_injected_field_must_be_late_final` | 변경 가능하거나, late가 아니거나, static인 필드의 `@injected` |
| `cobalt_injectable_must_be_constructible` | 추상 클래스나 public 생성(generative) 생성자가 없는 클래스의 `@CobaltInject` |
| `cobalt_init_requires_init_method` | `init()`이 없는 클래스의 `@CobaltInit` |
| `cobalt_bootstrap_requires_run_method` | `run()`이 없는 클래스의 `@CobaltBootstrap` |
| `cobalt_bootstrap_step_cannot_inject` | 생성자가 필수 파라미터를 받는 부트스트랩 단계 |
| `cobalt_environment_needs_a_registration` | 아무것도 등록하지 않는 클래스의 `@CobaltEnvironment` |
| `cobalt_dependency_is_not_registered` | 패키지 안에서 아무것도 등록하지 않는 주입 의존성, 또는 아무것도 등록하지 않는 데코레이터의 대상이나 의존성 |
| `cobalt_dependency_cycle` | 결국 자기 자신에 의존하는 주입 가능 클래스. 자신의 데코레이터를 거치는 경우도 포함합니다 |
| `cobalt_registration_is_never_released` | 스코프가 볼 수 없는 `dispose()` 또는 `close()`를 가진 등록된 클래스 |
| `cobalt_resource_is_never_closed` | 등록이 닫아야 하는 무언가를 보유하면서 그것을 닫을 방법을 제공하지 않음 |
| `cobalt_lazy_registration_injected_synchronously` | 기다릴 수 없는 곳에 주입된 지연 비동기 등록: 동기 또는 즉시 생성 생성자, `@injected` 필드, 데코레이터 |
| `cobalt_async_transient_read_synchronously` | 비동기 트랜지언트에 대한 `get`, `getOrNull`, `getAll` 또는 `context.cobalt`. 항상 예외를 던지므로 `getAsync`로 해석하십시오 |
| `cobalt_depends_on_lazy_registration` | 지연 비동기 등록을 지목하는 `@CobaltInit(dependsOn: [...])`. `init()`은 그것을 빌드하지 않습니다 |
| `cobalt_override_needs_type_argument` | 타입 인자가 없는 `CobaltOverride` 또는 `CobaltParamOverride`. 이 경우 교체할 키를 Dart가 추론합니다 |
| `cobalt_hook_added_too_late` | 같은 스코프에서 즉시 생성 등록이나 `get` 이후에 호출한 `hookAll`(같은 캐스케이드 안이든 블록의 앞부분이든). 스코프가 `CobaltHookError`로 거부하므로, 무엇이든 빌드되기 전에 훅을 추가하십시오 |

이 중 일곱 개 규칙은 IDE에서 빠른 수정(quick fix)도 제공합니다. 빠진 `late final`, 믹스인, `@cobaltInject`,
`lazy: true`, `implements Disposable`을 대신 써 줍니다. 어떤 규칙이 무엇을 고치는지는
[패키지 README](packages/cobalt_lint/README.md#quick-fixes)에 정리되어 있습니다.

플러그인을 연결할 때 실제로 시간을 잡아먹는 것이 두 가지 있습니다:

1. `plugins:` 섹션은 **패키지나 워크스페이스의 루트에서만 동작합니다**. 중첩된 `analysis_options.yaml`에서는
   조용히 무시됩니다. 오류도, 진단도 없습니다. 같은 이유로 `dart analyze <nested/dir>`도 이를 적용하지 않으므로,
   워크스페이스 루트를 분석하십시오.
2. 분석 서버는 컨텍스트마다 플러그인 빌드를 캐시합니다. "규칙이 동작하지 않는다"는 대개 규칙이 틀린 것이 아니라
   빌드가 오래된 것입니다. 플러그인 파일을 touch하거나 서버를 다시 시작하십시오.

마지막 두 규칙은 제너레이터도 답하는 질문에 답하되, 더 일찍, 전체 빌드 없이 답합니다. 이 규칙들은 의도적으로
제너레이터보다 조용합니다. 패키지의 구문 인덱스를 읽으므로, 인덱스가 확신할 수 없는 곳에서는 문제없는 것을
보고하는 대신 아무 말도 하지 않습니다. 최종 판단은 빌드가 내리고, 에디터는 빠른
경로입니다.

---

## 17. 그래프 관찰하기

옵저버는 스코프가 생기고, 인스턴스가 빌드되고, 시작이 끝나고, 해제가 실패하는 것을 봅니다. 그래프를 만드는
곳에서 넘기십시오. 그 아래로 push되는 모든 스코프가 이를 물려받습니다.

`$startCobalt()`는 옵저버를 받지 않습니다. 이것은 짧은 경로입니다. 옵저버가 필요해지면 이미 조합하고 있는
빌더를 거치십시오:

```dart
final scope = await CobaltApplication.start(
  root: const NotesScope(notesEnvironment),
  bootstrap: $cobaltBootstrap(notesEnvironment),
  rootName: $cobaltRootScopeName,
  observers: [CobaltLogObserver(const CobaltDeveloperLogSink())],
);
```

Flutter 앱에서는 `CobaltAppScope.builder`의 `observers:` 파라미터입니다.

콜백은 살아 있는 객체가 아니라 설명인 `CobaltScopeRef`와 `CobaltKey`를 받으며, 콜백에서 발생한 예외는
삼켜집니다. 지켜보는 쪽이 지켜보는 대상을 망가뜨릴 수 있어서는 안 됩니다. 해석은 보고되지 않습니다. 캐시
적중은 핫 패스이며, 볼 가치가 있는 것은 인스턴스가 *빌드되는* 순간입니다.
빌드마다 시간을 잽니다. `onInstanceBuilt`가 `onInstanceCreated` 다음에 걸린 시간과 함께 호출되며(그 빌드가
해석한 빌드와 모든 `await`를 포함한 전체 경과 시간), 로그 옵저버는 이를 같은
줄에 기록합니다.

그 직전에 `onInstanceSelfTime`이 그중 빌드가 자기 자신에 쓴 시간, 즉 기다린 다른 빌드를 뺀 시간을 알려 주며,
로그 기록은 이를 `selfTook`으로 담습니다. 느린 곳을 찾아 주는 것은 이 숫자입니다. 느린 의존성을 해석하는
클래스의 전체 시간은 대부분 그 의존성의 시간이기 때문입니다.

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

## 18. 테스트

가장 먼저 알아야 할 것은 API가 아니라 함정입니다. `testWidgets`는 본문을 fake-async 존 안에서 실행하며,
그 안에서는 초기화의 `Future.delayed`가 영원히 완료되지 않습니다. **그래프는 `setUp`에서 빌드하고**, 그래프
전체에 대한 단언은 평범한 `test`에 두십시오.

```dart
late CobaltScope scope;

setUp(() async {
  scope = await cobaltTestScope(root: const $CobaltRootScope());
});
```

생성된 빌더를 앱이 쓰는 그대로 바로 넣습니다. `cobaltTestScope`와 `cobaltTestRoot`는 테스트와 함께
해제됩니다. 이 부분은 빠뜨리기 쉬운데, 빠뜨리면 테스트가 실패하는 것이 아니라 다음 테스트로 새어 나갑니다.

### 재정의

대체할 것은 생성된 시작 함수나, 그것을 호출하는 테스트 헬퍼에 넘기십시오. 재정의는 생성된 모든 것이 등록되는
루트에 들어가며, 같은 키의 생성된 등록은 중복으로 거부되는 대신
건너뜁니다:

```dart
final scope = await cobaltTestScope(
  root: const $CobaltRootScope(),
  overrides: [CobaltOverride<ApiClient>.value(FakeApiClient())],
);
```

`$startCobalt(overrides: [...])`는 같은 리스트를 받습니다. `CobaltAppScope(overrides: () => [...])`는 시작할
때마다 호출되는 함수를 받으므로, 재시작해도 이전 그래프가 이미 닫은 값을 다시 받지 않습니다. 앱에서는
플레이버나 디버그 메뉴가 이런 경우입니다. `.value`는 빌드된 객체를, `.lazy`와 `.transient`는 팩토리를,
`CobaltParamOverride<T, P>`는 파라미터가 있는 팩토리를 받습니다. 즉시 생성 싱글턴은 `registerEagerSingleton`으로
내보내지므로, 재정의된 것은 아예 빌드되지 않습니다.

재정의는 결코 조용히 일어나지 않습니다. 옵저버는 `onRegistrationOverridden`을 받고, `overriddenKeys`는
무엇이 교체되었는지 나열합니다. 타입 인자를 명시하십시오. 리스트 안에서는 Dart가 이를 `Object`로 추론하며,
스코프는 생성되자마자 이를 거부합니다.

`CobaltScopeWidget`, 스코프를 가진 위젯들, 플로우를 소유하는 모든 라우트도 스코프가 생성될 때마다 호출되는
함수 형태로 `overrides`를 받습니다. 위젯 테스트에서 대역을 끼운 채 화면 하나를 마운트하는 방법이 이것입니다.
이것들은 해당 스코프가 등록하는 것을 교체합니다. 조상이 소유한 키는 조상에서 재정의하며, 자식에게 이를
요청하면 소유자를 지목하며 실패합니다.

자식 스코프에서의 섀도잉도 여전히 동작하며, 자식에서 해석되는 것에만 닿습니다:

```dart
final overrides = scope.pushForTest()
  ..registerSingleton<ApiClient>(FakeApiClient());
```

**팩토리는 자기 등록을 소유한 스코프에서 실행되며**, 생성된 모든 것은 루트에 있으므로, 생성된 모든 소비자는
실제 `ApiClient`를 계속 씁니다. `ownerOf<T>()`가 테스트보다 먼저
답해 줍니다:

```dart
expect(scope.ownerOf<Repository>(), same(scope.root));
```

### 런타임에 여전히 검사해야 하는 것

완전성 검사는 생성된 컨테이너를 다룹니다. 그 밖에 놓인 두 가지는 테스트할 가치가
있습니다:

```dart
await expectGraphResolves(scope);
```

첫째는 `provides:`로 약속한 모든 것입니다. 검사는 여러분을 믿었습니다. 둘째는 조합해 넣은 직접 작성한
등록입니다([§6](#6-생성된-루트-위에-조합하기)).

이 검사는 되돌릴 수 없습니다. 해석하는 것 *자체가* 검사이므로, 그 뒤에는 모든 지연 싱글턴이 빌드되어 있고 해제
순서도 달라집니다. 별도의 테스트에 두십시오. 파라미터가 있는 등록은 조용히 건너뛰는 대신 이름과 함께
`unchecked`로 보고됩니다. 검사하려면 예시 값을 넘기십시오:

```dart
await expectGraphResolves(scope, params: {CobaltKey(Greeting): (name: 'x', loud: false)});
```

### 그래프의 형태 지키기

그래프를 완전하게 지키는 것은 제너레이터이고, 그 형태의 변화를 보여 주는 것은 스냅숏입니다. 지연 싱글턴이 된
`@cobaltTransient`는 바뀐 줄 하나로 읽힙니다. `describeGraph`는 각 스코프의 등록(종류, 재정의, 데코레이터)을
아무것도 빌드하지 않고 렌더링하며, `expectGraphSnapshot`은 그것을 테스트 옆에 보관한 파일과
비교합니다:

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

### 픽스처

```dart
final scope = cobaltTestRoot()
  ..registerLazySingleton<Clock>(FnFactory((_) => FixedClock(DateTime(2026))))
  ..registerSingleton<Config>(const Config())
  ..registerAsyncSingleton<Db>(AsyncFnFactory((_) async => Db()));

await scope.init();
```

이것들 덕분에 생성된 그래프 전체가 필요 없는 테스트에서 스텁마다 팩토리 클래스를 작성하지 않아도 됩니다.
비동기 등록은 `init()` **전에** 존재해야 하므로, 픽스처는 이미 시작된 스코프가 아니라 새 루트에
넣습니다.

`DisposeRecorder`는 해제를 단언하기 위한 픽스처로, 공유 로그가 아니라 인스턴스마다 로그를 가지므로, 자신을
만든 테스트가 끝난 뒤에 해제된 스코프가 다음 테스트에 기록을 남길 수 없습니다.
`CapturingObserver`는 그래프가 한 일에 대해 단언할 수 있도록 이벤트를 모읍니다.

### 위젯 테스트

`cobalt_test_flutter`에는 뻔해 보이는 작성법이 틀린 두 가지 경우를 위한 헬퍼가 있습니다:

```dart
await settle(tester);                    // pumpAndSettle이 아닙니다: 로딩 인디케이터에서 영원히 돕니다
final scope = mountedRootScope(tester);  // 앱의 그래프, MaterialApp builder 아래에서 가져옵니다
```

### CI에서 생성된 코드를 정직하게 유지하기

다시 생성하고, diff가 있으면 실패시키십시오:

```bash
dart run build_runner build
git diff --exit-code
```

이것이 없으면 생성된 출력이 어노테이션과 어긋나도, 런타임에 그래프가 잘못될 때까지 아무도
알아차리지 못합니다.

---

## 19. 미리 알아 둘 만한 실수

아래는 모두 이 저장소에서, 또는 이 저장소가 작성된 대상 애플리케이션에서 직접 겪으며 알게 된 것입니다.

- **`cobalt.g.dart`를 커밋하지 않거나, 오래된 것을 커밋함.** CI에서 다시 생성하고 diff하십시오. 이 모드에서
  유일하게 실질적인 유지 관리 의무입니다.
- **한 패키지 안의 `@CobaltScopeRoot` 클래스 두 개.** 빌드 오류이며, 해결책은 패키지 두 개입니다.
  `cobalt_container`는 패키지 전체를 루트 하나로 집계합니다.
- **`instantiations` 없는 제네릭 클래스의 `@CobaltInject`.** 거부됩니다. 어떤 인스턴스화를 등록할지
  제너레이터에 알려 주는 것이 없습니다. `@CobaltInject(instantiations: [Cache<Note>, Cache<User>])`처럼
  모든 타입 인자를 명시해 나열하거나, 구체 하위 타입에 어노테이션을 붙이십시오. `instantiations`와 함께
  쓰는 `exposeAs`는 타입 인자 없이 씁니다. 제네릭은 의존성으로도,
  `exposeAs` 대상으로도 문제없이 동작합니다.
- **`with _$ClassName` 없는 `@injected`.** 필드는 할당되지 않은 채 남고 첫 읽기가 `LateError`를 던집니다.
  린트가 먼저 알려 줍니다.
- **`provides:`로 약속하고 등록하지 않음.** 검사는 여러분을 믿었으므로 실패가 런타임으로 옮겨 갑니다.
  `expectGraphResolves`로 확인하십시오.
- **`testWidgets` 안에서 그래프 빌드.** fake-async, 완료되지 않음, 가리킬 대상이 없는 타임아웃.
  `setUp`을 쓰십시오.
- **소비자보다 아래에서 재정의.** 팩토리는 소유한 스코프에서 실행됩니다. `ownerOf<T>()`가 단언보다 먼저
  알려 줍니다.
- **스코프가 소유한 bloc에 `BlocProvider(create:)` 사용.** 소유자가 둘이 되고, 위젯이 먼저 이깁니다.
  `BlocProvider.value`를 쓰십시오.
- **닫을 수 있다고 명시하지 않고 등록한 `ChangeNotifier`나 `Cubit`.** 빌드되고, 사용되고, 조용히 영영
  닫히지 않습니다. `implements Disposable`, `with CobaltBloc`, 또는 `dispose:`를 쓰십시오.
- **PATH에서 먼저 잡히는 오래된 `dart`.** 엉뚱한 곳에서 조용히 실패합니다. `dart analyze`는 엉뚱한 analyzer를
  기준으로 있지도 않은 문제를 보고하고, 생성된 출력은 포매터 버전에 따라 달라집니다.
  실행 결과를 믿기 전에 `dart --version`을 확인하십시오.

---

## 다음으로 읽을 것

- [GUIDE_MANUAL.ko.md](GUIDE_MANUAL.ko.md): 빌드 단계 없이 같은 런타임을 쓰는 방법, 그리고 무엇이 무엇과
  조합되는지.
- [docs/OVERVIEW.ko.md](docs/OVERVIEW.ko.md): Cobalt가 무엇인지, 그리고 각 결정이 왜 그렇게 내려졌는지.
- [MIGRATION.ko.md](MIGRATION.ko.md): `get_it`과 `injectable`에서 옮겨 오는 방법, 대응되지 않는 것까지 포함해서.
- `examples/codegen_basics`는 가장 작은 생성 구성이고, `examples/notes_app`은 가장 큰 구성입니다.
  둘 다 갤러리에서 실행됩니다: `cd examples/gallery && flutter run`.
