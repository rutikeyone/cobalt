# hello

The smallest Cobalt app: two classes, one screen. It is the code from the README's Quick start,
kept here so it is compiled and tested.

## Run it

This folder has no platform projects, so start a new app and copy the code in:

```bash
flutter create my_app && cd my_app
flutter pub add cobalt cobalt_flutter dev:cobalt_generator dev:build_runner
rm test/widget_test.dart
```

Replace `lib/main.dart` with [this one](lib/main.dart), then:

```bash
dart run build_runner build
flutter run
```

`test/widget_test.dart` goes because it tests the counter app `flutter create` wrote, which is gone.

## What it shows

- `@cobaltInject` on a class registers it. `Greeter` asks for a `Clock` in its constructor, and the
  generator wires it — `lib/cobalt.g.dart` is what it wrote.
- `CobaltAppScope.builder` builds the graph when the app starts and closes it when the app goes.
- `context.cobalt<Greeter>()` reads from the graph in a widget.
- The test swaps `Clock` for a fixed one with `CobaltOverride`, so the greeting does not depend on the
  time of day.

## Where to go next

1. **A scope of your own.** The *Session scope* entry in [`examples/gallery`](../gallery): signing
   in pushes a scope, signing out closes it with everything it built. The code is in
   [`notes_app/lib/features/session`](../notes_app/lib/features/session).
2. **A test that swaps a dependency.** [`examples/testing_patterns`](../testing_patterns).

To the side: [`examples/codegen_basics`](../codegen_basics) for what else the generator does
(property injection, a decorator, a scope per screen), and
[GUIDE_CODEGEN.md](../../GUIDE_CODEGEN.md) for the same mode, step by step.
