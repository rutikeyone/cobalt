<p align="center">
  <a href="MIGRATION.md">English</a> · <a href="MIGRATION.ru.md">Русский</a> · <a href="MIGRATION.zh-CN.md">中文</a> · <a href="MIGRATION.ko.md">한국어</a>
</p>

> 이 문서는 [MIGRATION.md](MIGRATION.md)를 번역한 것입니다. 영어판이 기준이며, 내용이 다르면 영어판을 따릅니다.

# Cobalt로 마이그레이션하기

의존성 주입 없이 Flutter 앱을 시작한 다음에야 프레임워크를 고르러 나서는 사람은 없습니다.
여러분이 이 문서를 읽고 있는 것은 이미 `get_it`, 또는 `get_it` + `injectable`을 쓰고 있고,
그중 무언가가 규모를 감당하지 못하게 되었기 때문입니다.

이 가이드는 두 부분으로 나뉩니다. 무엇이 무엇에 대응되는지, 그리고 무엇이 전혀 대응되지 않는지입니다.
쓸모 있는 쪽은 두 번째 부분입니다.

이미 Cobalt 0.x 릴리스를 쓰고 있다면, 마지막의 [Cobalt 0.x에서 1.0으로](#cobalt-0x에서-10으로)에 바꿔야
할 것이 정리되어 있습니다.

## 마이그레이션을 버틸 만하게 만드는 단 하나의 규칙

**리프에서 안쪽으로 옮기십시오.** 아무것도 의존하지 않는 것부터 먼저 등록하고, Cobalt와 기존 컨테이너가
공존하게 두었다가, 루트 아래의 모든 것이 이미 Cobalt의 것이 된 다음에야 루트를
전환합니다.

Manual Mode는 바로 이것을 위해 존재합니다. 생성된 컨테이너와 직접 작성한 컨테이너는
같은 런타임이므로, 절반만 마이그레이션된 앱은 망가진 상태가 아니라 정상적인
상태입니다:

```dart
final app = await CobaltApplication.start(root: const AppScope());

// 아직 옮기지 않은 모든 것은 여전히 get_it에서 옵니다. 한 줄이며, 마지막에 지웁니다.
GetIt.I.registerSingleton<Database>(app.get<Database>());
```

루트 컴포넌트부터 전환하고 싶은 유혹을 참으십시오. 루트는 간선이 가장 많은 컴포넌트이고,
그 의존성이 Cobalt의 것이 되기 전까지는 얻는 것이 없습니다.

## get_it → Cobalt

### 등록

| get_it | Cobalt |
|---|---|
| `registerFactory<T>(() => T())` | `registerFactory<T>(const TFactory())` |
| `registerSingleton<T>(instance)` | `registerSingleton<T>(instance)` |
| `registerLazySingleton<T>(() => T())` | `registerLazySingleton<T>(const TFactory())` |
| `registerSingletonAsync<T>(() async => …)` | `registerAsyncSingleton<T>(const TFactory())` |
| `registerSingletonWithDependencies<T>(…, dependsOn: [A])` | `registerAsyncSingleton<T>(…, dependsOn: {CobaltKey(A)})` |
| `registerLazySingletonAsync<T>(() async => …)` | `registerLazyAsyncSingleton<T>(const TFactory())` |
| `registerFactoryAsync<T>(() async => …)` | `registerAsyncFactory<T>(const TFactory())`, `getAsync`로 읽습니다 |
| `registerFactoryParam<T, P, void>((p, _) => …)` | `registerParamFactory<T, P>(const TFactory())` |
| `registerFactoryParamAsync<T, P, void>((p, _) async => …)` | `registerAsyncParamFactory<T, P>(const TFactory())`, `getAsyncWithParam`으로 읽습니다 |
| `getIt<T>()` / `getIt.get<T>()` | `scope.get<T>()` |
| `getIt<T>(instanceName: 'a')` | `scope.get<T>(name: 'a')` |
| `await getIt.getAsync<T>()` | `await scope.getAsync<T>()` |
| `getIt.isRegistered<T>()` | `scope.isRegistered<T>()` |
| `pushNewScope(...)` | `scope.push('name')` |
| `popScope()` | `await child.dispose()` |
| `reset()` | `await root.dispose()` |
| `allowReassignment = true` 또는 `unregister<T>()` 후 대역 등록 | `start`, `CobaltScope.root` 또는 테스트 헬퍼에 `overrides: [CobaltOverride<T>.value(fake)]` |

눈에 보이는 차이는 **클로저 대신 팩토리 객체**라는 점입니다. 이로써 두 가지를 얻습니다.
등록이 `const`일 수 있고, 그래프가 캡처된 상태가 아니라 살펴볼 수 있는 값이 됩니다.
제너레이터가 그래프를 내보내고 린터가 읽을 수 있는 것도 이 덕분입니다.

### 생명주기

`allReady()`와 `isReady<T>()`에는 대응하는 것이 없고, 필요도 없습니다.
`CobaltApplication.start`는 비동기 그래프 전체가 준비된 뒤에야 반환하므로,
폴링할 것도 조정할 타임아웃도 없습니다:

```dart
// get_it
GetIt.I.registerSingletonAsync<Database>(() => Database.open());
await GetIt.I.allReady(timeout: const Duration(seconds: 30));

// Cobalt
final app = await CobaltApplication.start(root: const AppScope());
```

`signalReady`와 수동 신호 모드에도 대응하는 것이 없습니다. Cobalt는 여러분이 알려 주는 것이
아니라 그래프로부터 준비 상태를 도출합니다.

### 스코프는 스택이 아니라 트리입니다

중요한 변화는 바로 이것이며, 기계적으로 옮기면 틀리는 부분도 이것입니다.

get_it의 스코프는 **평평한 LIFO 스택**입니다. `pushNewScope`는 언제나 그 하나의 스택에
push하고, `get<T>()`는 위에서 아래로 스택을 훑습니다. 서로 독립된 두 하위 트리,
예를 들어 각자 세션을 가진 탭 두 개는 표현할 수 없습니다.

Cobalt의 스코프는 **트리**를 이룹니다. `push`는 *그* 스코프의 자식을 만들고,
해석은 부모를 따라 루트까지 올라갑니다. 따라서:

```dart
final tabA = app.push('tab:a');
final tabB = app.push('tab:b');   // 형제이며, tabA 위에 쌓이지 않습니다
```

포팅할 때 실질적으로 달라지는 점:

- 실제로는 "임시 재정의"였던 `pushNewScope`/`popScope` 쌍은 그대로 옮겨집니다.
  서로 무관한 기능 사이의 스택 순서에 의존하던 쌍은 아마 트리에서는 불가능한 버그를 숨기고 있었을 것입니다.
- 해제는 선언 순서가 아니라 **생성 순서의** 역순(LIFO)입니다. 기존 해제 로직이 필드
  선언 순서에 의존했다면 이미
  취약했던 것입니다.
- 스코프를 만든 쪽이 해제합니다. 암묵적인 "현재 스코프"는 없습니다.

### Cobalt에 없는 것

옮기기로 결정하기 전에 다음을 알아 두십시오:

- **`registerFactoryParam<T, P1, P2>`**: Cobalt의 `registerParamFactory<T, P>`는
  파라미터를 하나만 받으며, 여러 개를 하나로 만드는 방법은 레코드입니다. 이름 있는
  형식 `({int id, String title})`을 권장합니다. 위치 기반 레코드와 달리 호출 위치와 팩토리 양쪽에
  이름이 남습니다. 레코드에는 컨테이너가 알 수 없는 값만 넣습니다. 의존성은 여전히 리졸버에서
  오므로, 레코드는 보통 그것이 대체하는 파라미터 목록보다 작습니다. Code-Gen Mode에서는 이 중
  아무것도 작성하지 않습니다. 파라미터에 `@CobaltParam`을 표시하면 제너레이터가 레코드 타입,
  팩토리, 등록을 내보냅니다.
- **`resetLazySingletons`**: 대신 스코프를 해제하십시오. 살아 있는 보유자 아래에서 인스턴스를
  리셋하는 것이야말로 스코프가 막으려는 종류의 버그입니다.
- **전역 인스턴스.** `GetIt.I`는 없습니다. 스코프는 전달되거나, 주입되거나, `context.cobalt<T>()`로
  위젯 트리에서 읽습니다. 이는 의도적입니다. get_it 그래프를 병렬로 테스트할 수 없게 만드는 것이
  바로 그 전역입니다.
- **리졸버 mock.** `CobaltResolver`는 `base` 클래스이므로 구현하거나 mock할 수 없습니다.
  그 덕분에 마이너 릴리스에서 확장될 수 있습니다. 테스트가 `GetIt`을 mock하던 곳에서는
  `cobalt_test`의 `cobaltTestRoot()`로 실제 스코프를 빌드해 거기에 대역을 등록하거나, 스코프의
  그래프에 재정의를 넘기십시오.

## injectable → Cobalt

### 어노테이션

| injectable | Cobalt |
|---|---|
| `@injectable` | `@cobaltTransient`: 해석할 때마다 새 인스턴스 |
| `@singleton` | `@cobaltSingleton`: 즉시 생성, 컨테이너가 조립될 때 빌드됩니다 |
| `@lazySingleton` | `@cobaltInject`: 기본값이며, 대부분의 경우 원하는 것 |
| `@Injectable(as: Foo)` | `@CobaltInject(exposeAs: Foo)` |
| `@Named('a')` | `@Named('a')` |
| `@Environment(Environment.dev)` | `@CobaltEnvironment.dev`: 여러 개면 어노테이션을 반복합니다 |
| `@preResolve` | `@CobaltInit()` |
| `@disposeMethod` | `implements Disposable` / `AsyncDisposable` |
| `@factoryMethod` | 첫 번째 public 생성(generative) 생성자, 그것이 아닐 때는 `@CobaltModule` 멤버 |
| `@factoryParam` | 생성자 파라미터에 붙인 `@CobaltParam` |
| `@InjectableInit()` + `configureDependencies()` | `@CobaltScopeRoot()` + 생성된 `$startCobalt()` |

### 형태가 바뀌는 것

**`@module`은 `@CobaltModule`이 되며, 거의 그대로입니다.** 형태는 거의 바뀌지 않고 넘어옵니다.
멤버가 여러분이 소유하지 않은 타입을 제공하는 클래스입니다:

```dart
// injectable
@module
abstract class AppModule {
  @lazySingleton
  Dio get dio => Dio();
}

// Cobalt
@cobaltModule
class AppModule {
  const AppModule();

  @cobaltInject
  Dio get dio => Dio();
}
```

차이는 세 가지입니다. 클래스는 추상 클래스가 아니라 **`const` 생성자를 가진 구체 클래스**입니다.
Cobalt가 하위 클래스를 생성하는 대신 `const AppModule()`에서 멤버를 호출하기 때문입니다.
**추상 멤버는 거부됩니다.** injectable에서 추상 멤버는 "자기 생성자로 빌드하라"는 뜻인데, 그것은
클래스에 붙인 `@CobaltInject`가 이미 뜻하는 바이고, 인터페이스에 바인딩하는 것은 `exposeAs`입니다.
그리고 `Future<T>`만으로 멤버가 비동기임이 표시되며, `@preResolve`는 없습니다.

**외부 타입에는 `@disposeMethod` 대신 `dispose:`를 씁니다.** 여러분이 소유한 클래스는
`Disposable`을 구현합니다. `Dio`는 그럴 수 없으므로 등록이 방법을 알려 줍니다:
`@CobaltInject(dispose: closeClient)`.

**`@Order`는 사라집니다.** injectable은 순서를 선언하게 하지만 Cobalt는 순서를 계산합니다.
등록은 컴파일 타임 위상 정렬로 정렬되며, 프로퍼티 주입 필드도 의존성 간선으로 셉니다.
순환이 있으면 스택 오버플로까지 재귀하는 대신 그 순환을 지목하며 빌드가
실패합니다.

**제네릭 클래스는 자기 인스턴스화를 나열합니다.** 그냥 `@CobaltInject class Cache<T>`만 쓰면
빌드 오류입니다. 어떤 인스턴스화를 등록할지 제너레이터에 알려 주는 것이 없기 때문입니다.
인스턴스화를 나열하면 각각이 별개의 등록이 되고, 자기 `Store<Note>` 또는 `Store<User>`로 만들어집니다.

```dart
@CobaltInject(instantiations: [Cache<Note>, Cache<User>])
class Cache<T> {
  Cache(this.store);
  final Store<T> store;
}
```

모든 타입 인자를 명시해야 하며, `exposeAs`는 `instantiations`와 함께 쓸 수 없습니다. `@injected` 필드는
쓸 수 있고, 믹스인이 타입 매개변수를 받습니다: `class Cache<T> with _$Cache<T>`.
제네릭 *의존성*은 평소대로 동작합니다. `Repository<User>`와 `Repository<Order>`는 별개의 등록입니다.

### 얻는 것

**프로퍼티 주입.** 컨트롤러가 생성자 인자를 다섯 개에서 열네 개까지 받는다면
이것이 전환할 이유입니다:

```dart
// 이전
class NotesCubit extends Cubit<NotesState> {
  NotesCubit({
    required this.repository,
    required this.telemetry,
    required this.session,
    required this.formatter,
    required this.config,
  }) : super(const NotesState());
  …
}

// 이후
@cobaltTransient
class NotesCubit extends Cubit<NotesState> with _$NotesCubit {
  NotesCubit() : super(const NotesState());

  @injected
  late final NoteStore _repository;

  @injected
  late final Telemetry _telemetry;
}
```

믹스인은 클래스 옆에 생성되어 생성 직후 필드를 채웁니다. 필드는 private이어도 됩니다.
part 파일이 같은 라이브러리에 있기 때문입니다. `late final`이 강제되므로, 두 번째 할당은
의존성을 조용히 바꾸지 않고 예외를 던집니다.

**실제 해제.** 스코프는 자신이 만든 것을 소유하고 생성의 역순으로 해체합니다.
로그아웃은 `await sessionScope.dispose()`가 되며, 어디에도 세션 리스너가 없고
도메인 인터페이스에 덧붙인 `reset()`도 없습니다.

## flutter_bloc과 provider → Cobalt

어느 쪽도 통째로 대체할 경쟁자가 아니며, 둘은 서로 다른 길을 갑니다.

**`provider`는 Cobalt의 `CobaltScopeProvider`가 이미 하는 일입니다.** 컨테이너를 트리 아래로
내려보내는 용도로만 쓴다면(직접 만든 DI가 하는 일이 바로 이것입니다) 그 용도는 사라집니다.
`CobaltAppScope`가 루트를 게시하고 `context.cobalt<T>()`가 그것을 읽습니다. 위젯 하위 트리 하나에
수명이 있는 객체를 주려고 `ChangeNotifierProvider`를 쓴다면 그것은 `CobaltScopeWidget`이며,
수명은 위젯의 수작업 관리가 아니라 스코프의 것이 됩니다.

**`flutter_bloc`은 전혀 대체되지 않습니다.** Cobalt는 bloc을 빌드하고, 렌더링은 여전히
`BlocBuilder`가 합니다. 생성하던 곳에서 해석하십시오:

```dart
BlocProvider.value(
  value: context.cobalt<CounterCubit>(),
  child: const CounterView(),
)
```

분명히 말해 둘 부분은 해제입니다. 스코프는 `Disposable` 또는 `AsyncDisposable`을 구현한 것을
해제하는데, `Cubit`은 `Future<void> close()`로 닫히므로 어느 쪽에도 해당하지 않습니다.
클래스마다 한 번 연결해 주십시오:

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {}
```

그 믹스인이 [`cobalt_bloc`](https://pub.dev/packages/cobalt_bloc)이며, 이 패키지는 이 한 문장을 위해
존재합니다. `implements AsyncDisposable`과 `Future<void> dispose() => close();`를 직접 작성해도
같은 효과입니다. 믹스인을 섞을 수 없는 bloc에는 함수를 지정하십시오:
`@CobaltInject(dispose: closeBloc)`. 그리고 `BlocProvider(create: ...)` 대신
`BlocProvider.value`를 쓰십시오. 전자는 넘겨받은 것을 닫아 버리지만, 그것은 여전히 스코프가 소유합니다.

`ChangeNotifier`는 그보다도 손이 덜 갑니다. 그 `dispose`가 이미 맞으므로 `implements Disposable`이
변경의 전부입니다. 어느 쪽이든 빠뜨리면 객체는 빌드되고 사용된 뒤 조용히 닫히지 않습니다. 전체 표는
[`cobalt_flutter` README](packages/cobalt_flutter/README.md)를 참고하십시오.

## 실제 진행 순서

1. `cobalt`와 `cobalt_annotations`를 추가합니다. 기존 컨테이너는 그대로 둡니다.
2. 아무것도 의존하지 않는 리프 서비스 두세 개로 루트 `CobaltScopeBuilder`를 작성합니다.
   `main`에서 기존 컨테이너와 나란히 시작합니다.
3. 브리지: 그 인스턴스들을 기존 컨테이너에 등록해 기존 호출 위치가 계속
   동작하게 합니다.
4. 그 리프의 소비자를 옮깁니다. 하나를 전환할 때마다 브리지가 한 줄 줄어듭니다.
5. 안쪽으로 반복합니다. 브리지는 단조롭게 줄어듭니다. 줄어들지 않는다면, 남은
   간선이 설계에 대해 무언가를 말해 주고 있는 것입니다.
6. 브리지가 비면 기존 컨테이너를 삭제하고 앱을
   `CobaltAppScope`로 전환합니다.
7. 이제야 코드 생성을 고려합니다. `cobalt_generator`를 추가하고, 직접 작성한
   등록을 한 번에 파일 하나씩 어노테이션으로 바꿉니다.

7단계가 마지막인 것은 의도적입니다. 코드 생성은 이미 신뢰하고 있어야 할 런타임 위의
편의 기능입니다.

## Cobalt 0.x에서 1.0으로

0.9에서는 바꿀 것이 없습니다. 1.0은 API를 동결한 0.9입니다. 이것이 무엇을 약속하는지는
[docs/OVERVIEW.ko.md](docs/OVERVIEW.ko.md#호환성)의 호환성 섹션을 참고하십시오. 더 오래된 0.x에서 올라오는 경우, 코드 컴파일을 깨뜨리는 변경은 다음과 같으며
오래된 것부터 나열합니다. 사용 중인 릴리스 이후의 것을 적용하십시오.

| 버전 | 변경 내용 | 할 일 |
|---|---|---|
| 0.2 | `CobaltRegistrationKind`, `CobaltDisposeStage`, `CobaltEventKind`에 값이 추가되었고 `CobaltResolver`에 메서드 두 개가 추가됨 | 완전한 `switch`에 case를 추가합니다. 더 좋은 방법은 종류의 getter에 묻는 것입니다(아래 참고). |
| 0.4 | `CobaltRegistrationKind.asyncParameterized`, `CobaltResolver`의 `getAsyncWithParam` | 위와 같습니다. |
| 0.5 | `CobaltRegistrationKind.asyncTransient` | 위와 같습니다. 0.7부터는 `isRetained`, `takesParam`, `isAsync`, `isBuiltByInit`이 `switch`로 묻던 것에 답하며, 종류가 추가되어도 계속 답합니다. |
| 0.6 | `CobaltRecordingObserver`가 생성 기록을 `onInstanceBuilt`에서 작성함 | `onInstanceCreated`를 오버라이드하고 기록을 위해 `super`를 호출하던 하위 클래스는 대신 `onInstanceBuilt`를 오버라이드합니다. |
| 0.7 | `CobaltResolver`가 `base` 클래스가 됨 | 그 mock이나 fake는 실제 스코프로 바꿉니다: `cobalt_test`의 `cobaltTestRoot()`에 대역을 등록하거나 재정의로 넘깁니다. |
| 0.8 | `CobaltError`가 `base` 클래스가 되고, 모든 패키지의 모든 오류가 `final`이 됨 | 전과 같이 catch합니다. 이를 구현하거나 상속하던 클래스는 직접 정의한 오류로 바꿉니다. |
| 0.9 | `CobaltHook`이 `base` 클래스가 됨 | `class X implements CobaltHook<T>`는 `final class X extends CobaltHook<T>`가 됩니다. `@override`는 그대로 둡니다. |

컴파일은 되지만 살펴볼 만한 동작 변경:

- **0.8**: `CobaltLogObserver`는 더 이상 `minimumLevel` 미만의 기록을 만들지 않습니다. 싱크는 원래
  그 기록을 보지 못했습니다. `onRecord`에서 걸러 내던 하위 클래스도 여전히 동작하며, `accepts`를
  오버라이드하면 비용이 더 줄어듭니다.
- **0.9**: 생성된 그래프의 그래프 스냅숏에 `as <Implementation>`과 `adopted: …` 줄이 추가됩니다.
  `COBALT_UPDATE_SNAPSHOTS=1`로 다시 실행하고, 커밋하기 전에 diff를 읽어 보십시오.
- **0.9**: debug 빌드에서 `CobaltAppScope`는 등록을 바꾼 핫 리로드 시 그래프를 다시 시작합니다.
  `restartOnGraphChange: false`로 이전 동작을 유지합니다.
- **1.0**: `CobaltScope`의 `debug*` 멤버는 `@experimental`입니다. 새로운 analyzer는 여러분의 코드가
  이를 호출하는 곳에서 `experimental_member_use`를 보고합니다. 마이너 릴리스에서 바뀔 수 있으므로,
  의도한 곳에서는 경고를 무시하십시오. 1.2부터 읽기 전용 멤버는 대신 deprecated로 바뀌었고,
  `registrationOf`, `describeTree()`를 비롯한
  [Inspecting a scope](packages/cobalt/README.md#inspecting-a-scope)의 멤버로 대체되며 2.0에서
  제거됩니다. `@experimental`로 남는 것은 `debugResolve…` 멤버뿐입니다.
