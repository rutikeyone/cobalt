# codegen_basics

The smallest generated setup, and a runnable template to copy.

> **Not a runnable app.** This package is a library the gallery mounts — it has no `main.dart`
> and no native project of its own. Run it, and everything else, from one place:
>
> ```bash
> cd examples/gallery && flutter run
> ```

```bash
dart run build_runner build
```

## What it shows

**Annotations in, container out.** `services.dart` and `counter_bloc.dart`
carry `@cobaltInject`, `@cobaltTransient` and `@injected`; `cobalt.g.dart` is
written from them, and there is no hand-written wiring anywhere. The generated
container is committed, so you can read exactly what the annotations produced.

**Property injection.** `CounterBloc` has an empty constructor and two
`late final` fields. The mixin beside it fills them right after construction —
this is the feature that removes five-to-fourteen-argument constructors from
controllers.

**A decorator.** `TrackedRepository` carries `@CobaltDecorates(Repository)`
and counts writes. The container wraps the one `Repository` it hands out, so
the bloc's injected field receives the wrapper and `Repository` itself is not
touched.

**A scope per screen.** `CobaltScopeWidget` gives the counter screen its own
node in the scope tree. It registers nothing yet, which is the point: that is
where screen-scoped state goes as the screen grows, and it is disposed when the
screen leaves.

## Where to go next

- `examples/manual_mode` — the same graph written by hand
- `examples/notes_app` — one screen per capability, the full surface
