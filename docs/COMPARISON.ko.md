<p align="center">
  <a href="COMPARISON.md">English</a> · <a href="COMPARISON.ru.md">Русский</a> · <a href="COMPARISON.zh-CN.md">中文</a> · <a href="COMPARISON.ko.md">한국어</a>
</p>

# 다른 패키지와 나란히 본 Cobalt

Dart나 Flutter 앱의 의존성에 어떤 패키지를 고를지, 그리고 Cobalt가 답이 아닌 경우는 언제인지 다룹니다.
이 페이지가 다른 패키지에 대해 말하는 내용은 2026-10-24에 pub.dev와 각 문서를 기준으로 확인했으며,
버전은 get_it 9.3.0, injectable 3.0.0, riverpod 3.4.3, provider 6.1.5+1, yx_scope 1.2.2입니다.
패키지는 계속 바뀌므로 [출처](#출처)의 링크에서 현재 상태를 확인하십시오.

## 한 줄씩

- **get_it**은 서비스 로케이터입니다. 한 번 등록하고 어디서든 `get`합니다. 생성할 코드가 없고, 사용자가
  가장 많으며, 스코프는 스택 하나입니다.
- **injectable**은 어노테이션으로 get_it 등록 코드를 씁니다.
- **riverpod**은 상태를 관리하며, 그 프로바이더가 수명과 대체를 갖춘 의존성도 담습니다.
- **provider**는 객체를 위젯 트리에 넣습니다.
- **yx_scope**는 컨테이너를 직접 작성하며, 중첩 스코프를 컴파일러가 확인합니다.
- **Cobalt**는 스코프가 트리를 이루고 자신이 만든 것을 닫는 컨테이너입니다. 제너레이터가 실행될 때 그래프를
  확인하고, 직접 작성한 코드도 같은 그래프에 들어갑니다.

## 나란히

| | Cobalt | get_it | injectable | riverpod | provider | yx_scope |
|---|---|---|---|---|---|---|
| **스코프** | 트리: 어떤 스코프든 자식을 가질 수 있고, 형제도 가능 | 스택 하나: `pushNewScope`, `popScope`, 이름 있는 스코프 | get_it의 스택: `@Scope`가 `init<Name>Scope`를 생성 | 컨테이너 하나; 하위 트리에는 `ProviderScope` 대체, 프로바이더마다 `autoDispose` | 위젯 하위 트리 | 깊이 제한 없이 중첩되는 컨테이너; `ScopeHolder`가 하나를 만들고 버림 |
| **닫기** | 스코프를 해제하면 그 스코프가 만든 모든 것을 최신 것부터 닫음 | `popScope`가 스코프의 객체를 등록 역순으로 해제 | `@disposeMethod`, `dispose:` | `ref.onDispose`; 듣는 곳이 없으면 `autoDispose` | 위젯이 떠날 때 `dispose:` | `drop`이 스코프의 의존성을 해제 |
| **없는 의존성** | `build_runner`가 실패하며 빠진 것을 모두 나열; 직접 작성하면 첫 `get`에서, 또는 테스트에서 `expectGraphResolves`로 | 첫 `get`에서 | 생성 중 경고; `throwOnMissingDependencies: true`면 오류 | 등록할 것이 없음: 프로바이더는 전역 선언 | 실행 중 `ProviderNotFoundException` | 컴파일러가 확인: 의존성이 컨테이너의 필드 |
| **코드 생성** | 선택; 생성된 등록과 직접 쓴 등록이 한 그래프에 | 없음 | 그 자체가 제너레이터 | 선택 (`riverpod_generator`) | 없음 | 없음 |
| **비동기 시작** | 비동기 싱글턴이 의존성 순서로 시작, 서로 무관한 것은 병렬, 타임아웃 포함 | 비동기 싱글턴, `dependsOn`, `allReady()` | `@preResolve`: 등록 전에 기다림 | `FutureProvider`; 순서는 각자가 무엇을 기다리는지에 따름 | `FutureProvider` 위젯 | 비동기 의존성, 스코프와 함께 초기화 |
| **Flutter 없이** | 예 | 예 | 예 | 예 (`riverpod`) | 아니오 | 예 (`yx_scope`) |
| **테스트에서 바꿔 끼우기** | 오버라이드가 등록이 사는 곳에서 그것을 대체; 전역 컨테이너가 없어 테스트가 병렬로 실행 | `allowReassignment`, `reset()`; 기본은 전역 `GetIt.I` 하나 | get_it과 같음 | `ProviderContainer`나 `ProviderScope`에서 오버라이드 | 위젯을 다른 프로바이더로 감쌈 | pub.dev 페이지에 설명 없음 |
| **pub.dev 좋아요 / 30일 다운로드** | 5 / 1.6K | 4.7K / 2.4M | 1.5K / 396K | 4.0K / 4.1M | 11K / 1.1M | 72 / 8.6K |

## Cobalt가 필요 없을 때

- **모든 것이 앱과 같은 수명입니다.** 로그아웃도, 상태를 가진 플로우도 없고, 서비스 몇 개를 `main`에서
  만듭니다. 생성자나 get_it이 더 간단합니다.
- **앱이 이미 riverpod 위에 있습니다.** 그 프로바이더에는 이미 수명과 대체가 있습니다. 컨테이너를 하나 더
  두면 그래프가 둘로 나뉘고, 각 절반이 서로를 알아야 합니다.
- **오랜 이력이 필요합니다.** Cobalt는 2026-09-30에 1.0이 되었고 아직 사용자가 적습니다. get_it, provider,
  riverpod에는 여러 해 동안 쌓인 질문과 답이 있습니다. Cobalt의 API는 1.0부터 안정적이고 모든 마이너
  릴리스가 깨지는 변경을 검사받지만, 그것은 약속이지 이력이 아닙니다.
- **제너레이터 없이, 스코프 빌더보다 적게 쓰고 싶습니다.** 수동 모드는 평범한 Dart이지만 그래도
  `registerSingleton`보다는 많이 씁니다.

## 효과가 있을 때

- 상태가 세션, 플로우, 화면에 속하고, 그것이 끝날 때 닫혀야 합니다.
- 첫 프레임 전에 시작해야 하는 서비스가 여럿이고, 그중 일부가 다른 것을 필요로 합니다.
- 없는 의존성이 어떤 화면에서 사용자에게 닿지 않고 빌드를 멈춰야 합니다.
- 테스트가 전역 컨테이너 없이 의존성 하나를 바꾸고, 병렬로 실행됩니다.

## 옮겨 오기

[MIGRATION.ko.md](../MIGRATION.ko.md)는 get_it, injectable, flutter_bloc, provider 코드를 하나씩 Cobalt에
대응시키고, Cobalt에 없는 것을 나열합니다.

## 출처

2026-10-24 확인:
[get_it](https://pub.dev/packages/get_it)과
[그 스코프](https://flutter-it.dev/documentation/get_it/scopes),
[injectable](https://pub.dev/packages/injectable)과
[`InjectableInit`](https://github.com/Milad-Akarie/injectable/blob/master/injectable/lib/src/injectable_annotations.dart),
[riverpod](https://pub.dev/packages/riverpod),
[provider](https://pub.dev/packages/provider),
[yx_scope](https://pub.dev/packages/yx_scope). 좋아요와 다운로드는 pub.dev API
(`/api/packages/<name>/score`)에서 가져왔으며, riverpod은 `flutter_riverpod`을 뺀 `riverpod` 패키지의 수치입니다.
