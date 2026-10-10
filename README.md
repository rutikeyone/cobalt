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

# Cobalt

Dependency injection for Flutter and Dart. Objects live in scopes — the app, a signed-in session, a
checkout flow, a screen — and when a scope ends, everything built in it is closed with it.

<p align="center">
  <img src="assets/quick-tour.gif" width="300" alt="A tour of the gallery: a session scope opened, then the live scope tree">
</p>

<p align="center"><sub>The gallery: open a session scope, then look at the live scope tree in <code>cobalt_inspector</code>.</sub></p>

## Quick start

In a Flutter app — `flutter create my_app` makes one — add the packages:

```bash
flutter pub add cobalt cobalt_flutter dev:cobalt_generator dev:build_runner
```

`cobalt` is the runtime: the generated code imports it, so the app depends on it directly.

Replace `lib/main.dart`:

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
    builder: CobaltAppScope.builder(root: const CobaltRoot()),
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

Delete `test/widget_test.dart` too: it tests the counter app that `flutter create` wrote, and that
app is gone.

Generate the wiring and run:

```bash
dart run build_runner build
flutter run
```

Until the build has run, the editor marks `cobalt.g.dart` and `CobaltRoot` as missing. That
is expected: the build writes them. If something else goes red, see [the first build](docs/TROUBLESHOOTING.md#the-first-build).

`@cobaltInject` registers a class. `Greeter` asks for a `Clock` in its constructor, and the generator
connects the two in `lib/cobalt.g.dart`. `CobaltAppScope` builds the graph when the app starts and
closes it when the app goes; `context.cobalt<Greeter>()` reads from it. The same app, with a test
that swaps the clock, is in [`examples/hello`](examples/hello).

## Next steps

Three steps, each one code you can run:

1. **One graph for the app.** [`examples/hello`](examples/hello): the code above, with its test.
2. **A scope of your own.** The *Session scope* entry in the gallery
   (`cd examples/gallery && flutter run`): signing in pushes a scope, signing out closes it with
   everything it built. The code is in
   [`examples/notes_app/lib/features/session`](examples/notes_app/lib/features/session).
3. **A test that swaps a dependency.** [`examples/testing_patterns`](examples/testing_patterns).

To the side: [`examples/codegen_basics`](examples/codegen_basics) shows what else the generator
does (property injection, a decorator, a scope per screen), and
[`examples/manual_mode`](examples/manual_mode) with [`examples/teardown`](examples/teardown) show the
runtime alone, in pure Dart.

## Why Cobalt

- **Scopes end, and take their objects with them.** Scopes form a tree. Sign-out is
  `await session.dispose()`: everything the session built is closed, newest first. No `reset()`
  methods, no listeners waiting for a logout event.
- **Mistakes show up at build time.** A dependency nothing registers fails `build_runner` with a
  message naming every gap at once. [Eighteen lint rules](packages/cobalt_lint/README.md) catch the
  rest in the editor.
- **The generated code is plain Dart.** It uses only the public API, so you can read it — or skip the
  generator and write the same thing by hand. Both can live in one graph.
- **Async startup in the right order.** Services that must be awaited before the first screen start
  in dependency order, independent ones in parallel.
- **Tests swap a dependency for everyone.** An override replaces a registration where it lives. There
  is no global container, so tests run in parallel.
- **You can see the graph.** `cobalt_inspector` shows the live scope tree and every event, inside the
  running app.

<p align="center">
  <img src="assets/screenshots/tree.png" width="30%" alt="The live scope tree">
  <img src="assets/screenshots/flow.png" width="30%" alt="A scope owned by a navigation flow">
  <img src="assets/screenshots/log.png" width="30%" alt="Everything the graph reported">
</p>

<p align="center"><sub>The live scope tree, a checkout flow that owns a scope, and everything the graph reported — <code>cobalt_inspector</code>, inside the running app.</sub></p>

## Learn more

| | |
|---|---|
| **Step by step, with the generator** | [GUIDE_CODEGEN.md](GUIDE_CODEGEN.md) |
| **Step by step, without code generation** | [GUIDE_MANUAL.md](GUIDE_MANUAL.md) |
| **Coming from get_it, injectable or provider** | [MIGRATION.md](MIGRATION.md) |
| **Something threw** | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — every error, and what to do |
| **Every feature, how it works, compatibility, performance** | [docs/OVERVIEW.md](docs/OVERVIEW.md) |
| **Every feature in one app** | `cd examples/gallery && flutter run` |
| **Working on Cobalt itself** | [CONTRIBUTING.md](CONTRIBUTING.md) |

## Packages

For an app you need `cobalt` and `cobalt_flutter`, plus `cobalt_generator` and `build_runner` if you
use code generation. Everything else is optional.

<details>
<summary>All fifteen packages</summary>

| Package | Depends on | Ships to apps |
|---|---|---|
| `cobalt_annotations` | `meta` | yes |
| `cobalt` | `cobalt_annotations` | yes, runtime core, no Flutter |
| `cobalt_flutter` | `cobalt`, `flutter` | yes |
| `cobalt_go_router` | `cobalt_flutter`, `go_router` | yes, optional |
| `cobalt_bloc` | `cobalt`, `bloc` | yes, optional |
| `cobalt_talker` | `cobalt`, `talker` | yes, optional |
| `cobalt_logging` | `cobalt`, `logging` | yes, optional |
| `cobalt_logger` | `cobalt`, `logger` | yes, optional |
| `cobalt_analyzer` | `cobalt_annotations`, `analyzer` | no |
| `cobalt_generator` | `cobalt_analyzer`, `build`, `source_gen`, `code_builder` | dev_dependency only |
| `cobalt_lint` | `cobalt_analyzer`, `analysis_server_plugin` | dev_dependency only |
| `cobalt_test` | `cobalt`, `test_api`, `matcher` | dev_dependency only |
| `cobalt_test_flutter` | `cobalt_flutter`, `flutter_test` | dev_dependency only |
| `cobalt_inspector` | `cobalt_flutter`, `flutter` | dev_dependency only |
| `cobalt_talker_flutter` | `cobalt_inspector`, `cobalt_talker`, `talker_flutter` | dev_dependency only |

</details>

## Requirements

Dart 3.10 and Flutter 3.38, or newer. Which analyzer your project ends up with, and why:
[docs/OVERVIEW.md](docs/OVERVIEW.md#requirements).

## Licence

MIT. See [LICENSE](LICENSE).
