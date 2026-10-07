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

> Перевод [README.md](README.md). Канонический текст — английский: при расхождении верен он.
> README отдельных пакетов не переводятся — это справочники по API.

# Cobalt

Внедрение зависимостей для Flutter и Dart. Объекты живут в скоупах — приложение, сессия
пользователя, флоу оформления заказа, экран, — и когда скоуп заканчивается, всё, что в нём создано,
закрывается вместе с ним.

## Быстрый старт

Во Flutter-приложении — его создаёт `flutter create my_app` — добавьте пакеты:

```bash
flutter pub add cobalt cobalt_flutter dev:cobalt_generator dev:build_runner
```

Замените `lib/main.dart`:

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

Сгенерируйте связи и запустите:

```bash
dart run build_runner build
flutter run
```

`@cobaltInject` регистрирует класс. `Greeter` просит `Clock` в конструкторе, и генератор связывает их
в `lib/cobalt.g.dart`. `CobaltAppScope` строит граф при старте приложения и закрывает его, когда
приложение уходит; `context.cobalt<Greeter>()` читает из него. То же приложение с тестом, который
подменяет часы, лежит в [`examples/hello`](examples/hello).

## Зачем Cobalt

- **Скоуп заканчивается и забирает свои объекты.** Скоупы образуют дерево. Выход из аккаунта — это
  `await session.dispose()`: всё, что создала сессия, закрывается, от новых к старым. Никаких
  методов `reset()` и подписок на событие выхода.
- **Ошибки видны на сборке.** Зависимость, которую никто не зарегистрировал, роняет `build_runner`
  с сообщением, где перечислены все пробелы сразу. [Восемнадцать правил линтера](packages/cobalt_lint/README.md) ловят остальное прямо
  в редакторе.
- **Сгенерированный код — обычный Dart.** Он использует только публичный API: его можно прочитать
  или обойтись без генератора и написать то же самое руками. Оба способа уживаются в одном графе.
- **Асинхронный старт в правильном порядке.** Сервисы, которые надо дождаться до первого экрана,
  стартуют в порядке зависимостей, независимые — параллельно.
- **Тест подменяет зависимость для всех.** Override заменяет регистрацию там, где она живёт.
  Глобального контейнера нет, поэтому тесты идут параллельно.
- **Граф можно увидеть.** `cobalt_inspector` показывает живое дерево скоупов и все события прямо в
  работающем приложении.

<p align="center">
  <img src="assets/screenshots/tree.png" width="30%" alt="Живое дерево скоупов">
  <img src="assets/screenshots/flow.png" width="30%" alt="Скоуп во владении навигационного флоу">
  <img src="assets/screenshots/log.png" width="30%" alt="Всё, о чём сообщил граф">
</p>

<p align="center"><sub>Живое дерево скоупов, флоу оформления заказа со своим скоупом и всё, о чём сообщил граф, — <code>cobalt_inspector</code> внутри работающего приложения.</sub></p>

## Что дальше

| | |
|---|---|
| **По шагам, с генератором** | [GUIDE_CODEGEN.ru.md](GUIDE_CODEGEN.ru.md) |
| **По шагам, без кодогенерации** | [GUIDE_MANUAL.ru.md](GUIDE_MANUAL.ru.md) |
| **Переход с get_it, injectable или provider** | [MIGRATION.ru.md](MIGRATION.ru.md) |
| **Все возможности, устройство, совместимость, производительность** | [docs/OVERVIEW.ru.md](docs/OVERVIEW.ru.md) |
| **Все возможности в одном приложении** | `cd examples/gallery && flutter run` |
| **Работа над самим Cobalt** | [CONTRIBUTING.md](CONTRIBUTING.md) (на английском) |

## Пакеты

Приложению нужны `cobalt` и `cobalt_flutter`, а с кодогенерацией ещё `cobalt_generator` и
`build_runner`. Остальное — по желанию.

<details>
<summary>Все пятнадцать пакетов</summary>

| Пакет | Зависит от | Попадает в приложение |
|---|---|---|
| `cobalt_annotations` | `meta` | да |
| `cobalt` | `cobalt_annotations` | да, ядро рантайма, без Flutter |
| `cobalt_flutter` | `cobalt`, `flutter` | да |
| `cobalt_go_router` | `cobalt_flutter`, `go_router` | да, опционально |
| `cobalt_bloc` | `cobalt`, `bloc` | да, опционально |
| `cobalt_talker` | `cobalt`, `talker` | да, опционально |
| `cobalt_logging` | `cobalt`, `logging` | да, опционально |
| `cobalt_logger` | `cobalt`, `logger` | да, опционально |
| `cobalt_analyzer` | `cobalt_annotations`, `analyzer` | нет |
| `cobalt_generator` | `cobalt_analyzer`, `build`, `source_gen`, `code_builder` | только dev_dependency |
| `cobalt_lint` | `cobalt_analyzer`, `analysis_server_plugin` | только dev_dependency |
| `cobalt_test` | `cobalt`, `test_api`, `matcher` | только dev_dependency |
| `cobalt_test_flutter` | `cobalt_flutter`, `flutter_test` | только dev_dependency |
| `cobalt_inspector` | `cobalt_flutter`, `flutter` | только dev_dependency |
| `cobalt_talker_flutter` | `cobalt_inspector`, `cobalt_talker`, `talker_flutter` | только dev_dependency |

</details>

## Требования

Dart 3.10 и Flutter 3.38 или новее. Какой analyzer достанется вашему проекту и почему:
[docs/OVERVIEW.ru.md](docs/OVERVIEW.ru.md#требования).

## Лицензия

MIT. См. [LICENSE](LICENSE).
