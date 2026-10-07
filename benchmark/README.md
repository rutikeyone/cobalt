# cobalt_benchmark

What Cobalt costs, measured next to [get_it](https://pub.dev/packages/get_it). Not
published; the numbers it prints are under **Performance** in
[docs/OVERVIEW.md](../docs/OVERVIEW.md#performance).

```
dart compile exe bin/main.dart -o /tmp/cobalt_benchmark && /tmp/cobalt_benchmark
dart run bin/main.dart --quick     # a moment per side — does it run, not how fast
```

Quote AOT numbers only. `dart run` is the JIT, whose numbers depend on how far the
compiler has warmed up and are not what an app ships.

## What is measured

| Scenario | Per | Cobalt | get_it |
|---|---|---|---|
| get a built singleton | `get` | lazy singleton, already built | the same |
| build a transient with two dependencies | `get` | `registerFactory`, two lazy singletons | the same |
| register 200, then get each once | graph | fresh root scope, 200 named lazy singletons, each on the one before | fresh `GetIt.asNewInstance()`, `instanceName` |
| start 20 async singletons | start | `registerAsyncSingleton` ×20 + `init()` | `registerSingletonAsync` ×20 + `allReady()` |
| the transient, with an empty observer | `get` | a `CobaltObserver` that overrides nothing | — |
| the transient, with a recording observer | `get` | a `CobaltRecordingObserver` that drops each record | — |
| the transient, with a log observer at its default level | `get` | `CobaltLogObserver` with its default `minimumLevel` and a sink that writes nothing — what an app that logs has | — |

The last three have no get_it column because get_it has no observers; compare them with the
plain transient row. The recording observer is what `CobaltLogObserver` and the inspector's log
are built on, and it keeps every record, so its row is the price of a log that writes everything. The
last row is what an app that logs usually has: at its default level the log observer asks
`accepts(level)` before making a record, and the per-instance ones it would drop are never made.

Both sides are registered the same way (`lib/src/graph.dart`). Cobalt takes factories as
objects, so a closure is wrapped in one — the same single closure call get_it makes. Code
generation registers through these same calls, so the numbers hold for annotated classes
too. [injectable](https://pub.dev/packages/injectable) is not measured separately: it is
code generation on top of get_it, and resolves through it.

Scopes and containers built inside a measurement are dropped rather than disposed —
Cobalt's `dispose` is asynchronous, and neither side's teardown is what is being asked
about.

Timing is benchmark_harness's `measureFor`: each side runs for two seconds after a short
warm-up, and cheap operations are batched a thousand to a call so the timer does not
dominate. `test/scenarios_test.dart` checks that both sides do what each row says and
that every scenario runs; it is part of `tool/test.sh`.
