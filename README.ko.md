<p align="center">
  <img src="assets/banner.png" alt="Cobalt — dependency injection for Dart and Flutter" width="880">
</p>

<p align="center">
  <a href="https://pub.dev/packages/cobalt"><img src="https://img.shields.io/pub/v/cobalt?logo=dart&logoColor=white&label=pub&color=5FD4C8" alt="pub package"></a>
  <a href="https://pub.dev/packages/cobalt/score"><img src="https://img.shields.io/pub/points/cobalt?color=5FD4C8" alt="pub points"></a>
  <a href="https://pub.dev/packages/cobalt"><img src="https://img.shields.io/pub/likes/cobalt?color=5FD4C8" alt="pub likes"></a>
  <a href="https://github.com/rutikeyone/cobalt/actions/workflows/ci.yml"><img src="https://github.com/rutikeyone/cobalt/actions/workflows/ci.yml/badge.svg" alt="ci"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="licence"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh-CN.md">中文</a> · <a href="README.ko.md">한국어</a>
</p>

> 이 문서는 [README.md](README.md)를 번역한 것입니다. 영어판이 기준이며, 내용이 다르면 영어판을 따릅니다.
> 각 패키지의 README는 번역하지 않습니다. 해당 문서는 API 레퍼런스입니다.

# Cobalt

Flutter와 Dart를 위한 의존성 주입입니다. 객체는 스코프 안에 삽니다. 앱 전체, 로그인한 세션, 결제
플로우, 화면 하나가 각각 스코프이고, 스코프가 끝나면 그 안에서 만든 모든 것이 함께 닫힙니다.

## 빠른 시작

Flutter 앱(`flutter create my_app`으로 만들 수 있습니다)에 패키지를 추가합니다.

```bash
flutter pub add cobalt cobalt_flutter dev:cobalt_generator dev:build_runner
```

`lib/main.dart`를 다음으로 바꿉니다.

```dart
import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';

import 'cobalt.g.dart';

@cobaltInject
class Clock {
  Clock();

  DateTime now() => DateTime.now();
}

@cobaltInject
class Greeter {
  Greeter(this.clock);

  final Clock clock;

  String greet(String name) =>
      clock.now().hour < 12 ? 'Good morning, $name!' : 'Hello, $name!';
}

void main() => runApp(
  MaterialApp(
    builder: CobaltAppScope.builder(root: const $CobaltRootScope()),
    home: const HomeScreen(),
  ),
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final greeter = context.cobalt<Greeter>();
    return Scaffold(body: Center(child: Text(greeter.greet('Cobalt'))));
  }
}
```

연결 코드를 생성하고 실행합니다.

```bash
dart run build_runner build
flutter run
```

`@cobaltInject`는 클래스를 등록합니다. `Greeter`는 생성자에서 `Clock`을 요구하고, 제너레이터가
`lib/cobalt.g.dart`에서 둘을 연결합니다. `CobaltAppScope`는 앱이 시작될 때 그래프를 만들고 앱이
끝날 때 닫으며, `context.cobalt<Greeter>()`는 그래프에서 값을 읽습니다. 시계를 바꿔 끼우는 테스트까지
포함한 같은 앱이 [`examples/hello`](examples/hello)에 있습니다.

## 왜 Cobalt인가

- **스코프가 끝나면 객체도 함께 정리됩니다.** 스코프는 트리를 이룹니다. 로그아웃은
  `await session.dispose()`이고, 세션이 만든 모든 것이 최신 것부터 닫힙니다. `reset()` 메서드도,
  로그아웃 이벤트 구독도 필요 없습니다.
- **실수는 빌드 시점에 드러납니다.** 아무도 등록하지 않은 의존성이 있으면 `build_runner`가 실패하고,
  메시지 하나에 빠진 것을 모두 보여 줍니다. 나머지는 [열여덟 개의 린트 규칙](packages/cobalt_lint/README.md)이 편집기에서 잡습니다.
- **생성된 코드는 평범한 Dart입니다.** 공개 API만 사용하므로 읽을 수 있고, 제너레이터 없이 같은 코드를
  직접 작성할 수도 있습니다. 두 방식은 한 그래프 안에 함께 있을 수 있습니다.
- **비동기 시작이 올바른 순서로 진행됩니다.** 첫 화면 전에 기다려야 하는 서비스는 의존성 순서대로,
  서로 독립적인 것은 병렬로 시작됩니다.
- **테스트의 교체는 모두에게 적용됩니다.** override는 등록이 있는 바로 그곳에서 교체합니다. 전역
  컨테이너가 없으므로 테스트를 병렬로 실행할 수 있습니다.
- **그래프를 눈으로 볼 수 있습니다.** `cobalt_inspector`는 실행 중인 앱 안에서 실시간 스코프 트리와
  모든 이벤트를 보여 줍니다.

<p align="center">
  <img src="assets/screenshots/tree.png" width="30%" alt="실시간 스코프 트리">
  <img src="assets/screenshots/flow.png" width="30%" alt="내비게이션 플로우가 소유한 스코프">
  <img src="assets/screenshots/log.png" width="30%" alt="그래프가 보고한 모든 것">
</p>

<p align="center"><sub>실시간 스코프 트리, 자기 스코프를 가진 결제 플로우, 그리고 그래프가 보고한 모든 것. 실행 중인 앱 안의 <code>cobalt_inspector</code>입니다.</sub></p>

## 더 알아보기

| | |
|---|---|
| **단계별로, 제너레이터와 함께** | [GUIDE_CODEGEN.ko.md](GUIDE_CODEGEN.ko.md) |
| **단계별로, 코드 생성 없이** | [GUIDE_MANUAL.ko.md](GUIDE_MANUAL.ko.md) |
| **get_it, injectable, provider에서 옮겨 오기** | [MIGRATION.ko.md](MIGRATION.ko.md) |
| **모든 기능, 동작 방식, 호환성, 성능** | [docs/OVERVIEW.ko.md](docs/OVERVIEW.ko.md) |
| **모든 기능을 한 앱에서** | `cd examples/gallery && flutter run` |
| **Cobalt 자체 개발** | [CONTRIBUTING.md](CONTRIBUTING.md) (영어) |

## 패키지

앱에는 `cobalt`와 `cobalt_flutter`가 필요하고, 코드 생성을 쓰면 `cobalt_generator`와 `build_runner`도
필요합니다. 나머지는 선택입니다.

<details>
<summary>열다섯 개 패키지 전체</summary>

| 패키지 | 의존 대상 | 앱에 포함 |
|---|---|---|
| `cobalt_annotations` | `meta` | 예 |
| `cobalt` | `cobalt_annotations` | 예, 런타임 코어, Flutter 없음 |
| `cobalt_flutter` | `cobalt`, `flutter` | 예 |
| `cobalt_go_router` | `cobalt_flutter`, `go_router` | 예, 선택 |
| `cobalt_bloc` | `cobalt`, `bloc` | 예, 선택 |
| `cobalt_talker` | `cobalt`, `talker` | 예, 선택 |
| `cobalt_logging` | `cobalt`, `logging` | 예, 선택 |
| `cobalt_logger` | `cobalt`, `logger` | 예, 선택 |
| `cobalt_analyzer` | `cobalt_annotations`, `analyzer` | 아니요 |
| `cobalt_generator` | `cobalt_analyzer`, `build`, `source_gen`, `code_builder` | dev_dependency 전용 |
| `cobalt_lint` | `cobalt_analyzer`, `analysis_server_plugin` | dev_dependency 전용 |
| `cobalt_test` | `cobalt`, `test_api`, `matcher` | dev_dependency 전용 |
| `cobalt_test_flutter` | `cobalt_flutter`, `flutter_test` | dev_dependency 전용 |
| `cobalt_inspector` | `cobalt_flutter`, `flutter` | dev_dependency 전용 |
| `cobalt_talker_flutter` | `cobalt_inspector`, `cobalt_talker`, `talker_flutter` | dev_dependency 전용 |

</details>

## 요구 사항

Dart 3.10, Flutter 3.38 또는 그 이상. 프로젝트가 어떤 analyzer를 쓰게 되는지와 그 이유:
[docs/OVERVIEW.ko.md](docs/OVERVIEW.ko.md#요구-사항).

## 라이선스

MIT. [LICENSE](LICENSE)를 참고하십시오.
