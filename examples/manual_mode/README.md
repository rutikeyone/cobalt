# manual_mode

Cobalt without code generation, and without Flutter. Run it:

```bash
dart run bin/main.dart
```

## What it shows

**The runtime is the whole framework.** Everything here is written by hand, and
it is exactly what the generator would emit — that is the project invariant:
generated code may only use the public API of `cobalt`. If Manual Mode cannot
express something, generation must not either.

**It is pure Dart.** No Flutter binding, no widget tree, no `WidgetsBinding`.
The core runs in a CLI, on a server, or in a test with nothing mocked out.
`CobaltPrintLogSink` is the right observer sink here — `CobaltDeveloperLogSink`
wants a debugger attached to be worth anything.

**Scopes nest.** `openSession` pushes a child, the counter is resolved from it
with a runtime parameter, and disposing the session leaves the app's own
storage open. That parent/child split is the same one a Flutter app uses for
sign-out; nothing about it is UI-specific.

## Where to go next

- `examples/codegen_basics` — the same ideas with the generator doing the typing
- `examples/teardown` — what disposal guarantees when things go wrong

## Console output stays in English

There are no screens here, and the language of a command-line teaching program is not worth
dragging `intl` into a pure-Dart package for — the point of this example is that the runtime works
without Flutter at all. Everything the gallery *shows* is translated into English, Russian,
Chinese and Korean; see [`examples/gallery`](../gallery/README.md).
