# teardown

What disposal actually guarantees. Pure Dart — the output *is* the lesson:

```bash
dart run bin/main.dart
```

## What it shows

**Order is LIFO by creation, not by declaration.** `Cache` is registered before
`Database` but built first, and building it is what creates `Database`. So the
teardown order inverts the declaration order. This is the case hand-rolled
containers get wrong: they dispose a fixed list of fields in the order the
fields were written, which is only correct by accident.

**Async disposal is awaited.** The scope does not move on until an
`AsyncDisposable` says it is done.

**`adopt` ties a non-dependency to the scope.** `TempDirectory` is never
resolved by anything, but its life is the scope's all the same.

**Teardown is best-effort under one deadline.** `FlakySocket` throws on the way
out and `StuckWatcher` never returns — and the database still closes. Both
problems are collected into `CobaltDisposeError` (`failures`, `hasTimeout`), the
remaining services still run, and the scope still reaches `disposed`. The
deadline is global to the teardown, not per service.

That last part is the difference between "dispose is implemented" and "dispose
can be relied on". A container that aborts teardown at the first exception
leaks everything after it, and one with no deadline hangs forever on a single
stuck resource.

## Console output stays in English

There are no screens here, and the language of a command-line teaching program is not worth
dragging `intl` into a pure-Dart package for — the point of this example is that the runtime works
without Flutter at all. Everything the gallery *shows* is translated into English, Russian,
Chinese and Korean; see [`examples/gallery`](../gallery/README.md).
