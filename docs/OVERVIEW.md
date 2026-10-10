<p align="center">
  <a href="OVERVIEW.md">English</a> · <a href="OVERVIEW.ru.md">Русский</a> · <a href="OVERVIEW.zh-CN.md">中文</a> · <a href="OVERVIEW.ko.md">한국어</a>
</p>

# Cobalt in depth

What the [README](../README.md) leaves out: every feature, how it works inside, what the
compatibility promise covers, and what it costs.

## What it is

A container that owns what it builds. Scopes form a tree rather than a stack, so a session, a
checkout flow and a screen each get a lifetime of their own, and ending one takes everything built
inside it with it — logout is `await scope.dispose()`, not nine subscriptions to a session stream
and four `reset()` methods that leaked into domain interfaces.

Code generation is a convenience over that runtime, never a second framework. The generator emits
exactly what you would write by hand, using nothing but the public API of `cobalt`, which is what
makes gradual migration possible: a generated container and a hand-written one compose in the same
graph.

## Features

| | |
|---|---|
| **Hierarchical scopes** | a tree, not a flat stack — two independent subtrees can coexist, which a stack cannot express |
| **Ownership and teardown** | the scope releases what it built, LIFO by **creation** order, best-effort with one deadline for the whole tree |
| **Two-phase startup** | `@CobaltBootstrap` before the container exists, `@CobaltInit` inside it, both awaited before `start` returns |
| **Lazy async singletons** | built by the first `getAsync`, not at startup — for something expensive that lives as long as the app but few screens want |
| **Async transients** | `registerAsyncFactory`, or `@cobaltTransient` on an `@CobaltInit` class: every `getAsync` builds and awaits a new instance the scope does not keep |
| **Topological ordering** | async initializers are layered by Kahn's algorithm; independent branches run through `Future.wait`, a cycle fails the build naming the cycle |
| **Property injection** | `late final` fields filled by a generated mixin, so a class with five collaborators has an empty constructor |
| **Compile-time completeness** | a dependency nothing registers fails the build, naming every gap at once |
| **Parameterized registrations** | `@CobaltParam` for what the call site supplies; the generator writes the argument type as a named record. On an `@CobaltInit` class the build is async, awaited with `getAsyncWithParam` |
| **Optional dependencies** | `Foo?` resolves through `getOrNull` and injects null instead of failing the build |
| **Modules** | register types you did not write — a client from another package, a value the SDK hands you |
| **Decorators** | wrap what a registration hands out — logging, retries, a cache — without touching its class, by hand or with `@CobaltDecorates`; one registration or every registration of a type |
| **Hooks** | see every instance of a supertype the graph builds — each `Loggable` joining a registry — whichever registration built it, by hand or with `@cobaltHookAll`; unlike a decorator, it cannot replace the instance |
| **Environments** | one abstraction, a different implementation per build, with overlaps rejected at build time |
| **Named and multi-injection** | `@Named` qualifiers and `getAll<T>()` over every registration of a type |
| **Observability** | typed events, not strings — logging, structured intake and crash reports with a trail |
| **In-app inspector** | the live scope tree, what was built and with what lifetime, and everything reported |
| **Navigation flows** | a scope whose lifetime is a go_router flow, without anything mirroring the router |
| **Lint plugin** | eighteen rules on the same parsing layer the generator uses |
| **Overrides** | replace a registration where it is owned, so every consumer sees the double — in a test, a flavour or a debug menu |
| **Test helpers** | scopes that dispose with the test, overrides that work the way production ones do |
| **No global container** | nothing is ambient, so tests run in parallel and two graphs in one process are unrelated |

## Requirements

**Every package requires Dart `^3.10.0`, and the ones that need Flutter say `>=3.38.0`.** All
fifteen, including the generator and the lint plugin — an application still on Flutter 3.38 gets
both modes, not just Manual Mode.

Developed on Flutter 3.38.9 — the floor itself — and checked on the current `stable` and `beta`.

The floor has a mechanism behind it worth knowing, because it is not the Dart version that binds.
**Flutter 3.38 pins `meta 1.17.0`, and analyzer 10.0.2 wants `^1.18.0`** — so a Flutter application
on 3.38 tops out at analyzer 10.0.1, whatever its SDK constraint says. A pure-Dart consumer is not
bound by that and takes 12.1.0; 13.0.0 is out of reach for both, because it needs
`_fe_analyzer_shared 100`, which needs Dart 3.11.

So the three toolchain packages declare `analyzer: ">=10.0.1 <15.0.0"` rather than a single version,
and the same source builds and passes its tests on every row of it. Every package that reads the
analyzer pins it exactly, so which row you get is decided by your project rather than by us:

| your project | analyzer | analyzer_plugin | analysis_server_plugin | analyzer_testing | dart_style |
|---|---|---|---|---|---|
| Flutter 3.38 | 10.0.1 | 0.14.1 | 0.3.7 | 0.1.9 | 3.1.7 |
| anything newer, until something else needs analyzer 13 | 12.1.0 | 0.14.8 | 0.3.14 | 0.2.5 | 3.1.8 |
| Flutter 3.49's `test`, `build` 4.0.8+, current `freezed` or `json_serializable` | 13.x – 14.x | 0.14.9 – 0.14.17 | 0.3.15 – 0.3.23 | 0.2.6 – 0.4.2 | 3.1.9 – 3.1.13 |

The generator formats at a fixed language version, 3.10, rather than at whatever the resolved
`dart_style` calls latest — so every row emits identical bytes, and a formatter release that adds
style rules for a newer language version cannot change what is committed. That is checked rather
than assumed: CI's `verify` job regenerates on Flutter 3.38.9, which puts `codegen_basics` on the
10.0.1 row and the compatibility stand on 12.1.0, and diffs against what is committed; the `forward`
job on `beta` resolves the newest row and diffs the same files.

The repository is developed on that floor, and that is why it is not a pub workspace. A workspace is
one resolution, and on Flutter 3.38 `flutter_test` pins `test_api 0.7.7`, which caps the `test`
runner at 1.26.3 and the analyzer below 9, while `cobalt_analyzer` needs 10.0.1. So every package
resolves on its own and takes its siblings from a `pubspec_overrides.yaml` that `tool/overrides.py`
writes. CI's `verify` job runs everything on Flutter 3.38.9, and `forward` runs `stable` and `beta`
to find what is coming, rather than a matrix of past releases.

## Compatibility

Only a major release breaks, and its changelog says what under **Breaking**. Through the 0.x
releases any minor could; since 1.0 none does. Three rules say what that covers:

- **A new value in a public enum is a minor change.** `CobaltRegistrationKind` has grown in three
  releases and will again. Ask its getters — `isRetained`, `takesParam`, `isAsync`,
  `isBuiltByInit` — instead of switching over the values; an exhaustive `switch` is yours to update.
- **`CobaltResolver` cannot be implemented outside Cobalt.** It is a `base` class, so a new way of
  resolving arrives in a minor release. A test builds a real scope — `cobaltTestRoot` from
  `cobalt_test` — rather than a mock.
- **A new observer hook is a minor change.** `CobaltObserver` is a base class with empty hooks, so an
  observer written against an older release keeps compiling (`onInstanceBuilt` arrived that way). `CobaltHook`
  is built the same way.
  Anything you *implement* — factories, decorators, sinks, `Disposable` — gains members only in a
  major.

Two things are outside these rules on purpose. `CobaltScope`'s `debugResolve…` members, which the
inspector and `cobalt_test` resolve through, are marked `@experimental` and may change in a minor
release; newer analyzers flag each use from another package with `experimental_member_use`, which is
the point: ignore it where you mean it. And `cobalt_analyzer` is internal to the generator and the
lint plugin: its API follows what they need, not semver; depend on them rather than on it.

The read-only `debug…` members (`debugKindOf`, `debugDescribeTree` and the rest) are not an
exception: 1.2 deprecated them in favour of `registrationOf`, `describeTree()` and the rest of the
inspection API, and like any deprecated member they stay unchanged through 1.x and go in 2.0.

Coming from an older 0.x release: [MIGRATION](../MIGRATION.md#from-cobalt-0x-to-10) lists every change
that stops code compiling, and what to do about it.

`tool/api.sh` reports what changed in every package against the version on pub.dev, and
`tool/class_modifiers.txt` records every public type's class modifiers — the one change that tool
cannot see — so CI fails until a changed modifier is written down.

## Performance

Cobalt next to get_it, from [`benchmark/`](../benchmark/README.md), which describes what each row does.
Compiled AOT, on arm64 with Dart SDK 3.10.8 (stable, `macos_arm64`). Median of three runs; they agreed
within ten percent.

| | Cobalt | get_it | Cobalt / get_it |
|---|---:|---:|---:|
| get a built singleton | 81 ns | 425 ns | 0.19× |
| build a transient with two dependencies | 356 ns | 1.22 µs | 0.29× |
| register 200, then get each once | 137 µs | 386 µs | 0.35× |
| start 20 async singletons | 24.7 µs | 28.1 µs | 0.88× |
| the transient, with an empty observer | 374 ns | — | — |
| the transient, with a recording observer | 860 ns | — | — |
| the transient, with a log observer at its default level | 385 ns | — | — |

Below 1 in the last column, Cobalt took less time. The absolute numbers belong to this machine; what carries over is the order of
magnitude. A resolution costs well under a microsecond, a graph of 200 registrations a fraction of a
millisecond, the async start of twenty singletons tens of microseconds — none of it registers against
a 16 ms frame. An observer that turns every event into a record about doubles the cost of a build; the log
observer at its default level does not, because the per-instance records it drops are never made —
it costs what an observer that overrides nothing costs.

```
cd benchmark && dart compile exe bin/main.dart -o /tmp/cobalt_benchmark && /tmp/cobalt_benchmark
```

## How it works

### Scopes own what they build

A scope is a node with a parent, children and its own registrations. Resolution walks up, so a
registration in a child shadows one above it — which is how a session's repository replaces the
anonymous one in production. A factory runs on the scope that owns its registration, so a shadow
reaches only what is resolved below it; to replace a dependency for everything, an override is handed
to the scope that owns the key, and the real registration there is skipped.

Teardown is LIFO by **creation** order, not declaration order. That distinction is the bug in most
hand-written containers: a component declared first but created last is destroyed first, while
something still depends on it. And it is best-effort — a `dispose` that throws is recorded and the
rest still run, the whole tree shares one deadline, and what did not finish is listed in
`CobaltDisposeError` rather than the first failure hiding the other nine.

Parents hold children strongly. Weak references were considered and rejected: they would allow a
child scope to be collected before `dispose()` ran, which means never running it, and they do not
prevent leaks anyway because live objects inside hold themselves.

### The graph is checked before it builds

Code-Gen Mode rejects an incomplete graph at build time, naming every gap in one message:

```
Diagnostics requires DeviceInfo, which nothing registers. Annotate the class that
provides it with @CobaltInject, or name it in @CobaltScopeRoot(provides: [...]) when
something outside the generated container registers it.
```

Constructor parameters, `@injected` fields and `@CobaltInit(dependsOn:)` all count, a `@Named`
qualifier is part of the key, and each environment is checked separately. Duplicate registrations,
dependency cycles, two scope roots in one package, a generic injectable class that lists no
instantiations and an abstract one are all build failures too.

This is a Code-Gen guarantee, and the boundary is honest: a hand-written factory resolves inside
`create`, so nothing static can see what it will ask for. Manual Mode graphs still fail at runtime —
`cobalt_test` carries `expectGraphResolves` for exactly that gap.

### Generated code is what you would have written

Three builders: one writes property-injection mixins, one scans each library into IR, one aggregates
the whole package into `lib/cobalt.g.dart`. The aggregation is two-phase because a single build step
cannot see the whole program.

The output is private const factory classes and a `$CobaltRootScope`, ordered by a compile-time
topological sort — no closures, no reflection, no runtime scanning. `$cobaltBootstrap` is a getter
rather than a stored list, so a restart gets fresh steps instead of the ones the previous start
already consumed.

Generic types work as dependencies and as `exposeAs` targets — `Repository<User>` and
`Repository<Order>` are two registrations, because `CobaltKey` is built from `Type` and those are
different types. An injectable class may be generic too, as long as it lists the instantiations to
register; each one becomes a registration of its own, built with its own `Store<Note>` or
`Store<User>`:

```dart
@CobaltInject(instantiations: [Cache<Note>, Cache<User>])
class Cache<T> {
  Cache(this.store);
  final Store<T> store;
}
```

Every type argument is spelled out, and `exposeAs` is written without them: `exposeAs: Store`
exposes each instantiation as its own `Store<Note>`.
`@injected` fields work, with the mixin taking the type parameters: `class Cache<T> with _$Cache<T>`.

`cobalt_analyzer` exists so the generator and the lint plugin parse Cobalt declarations through one
implementation instead of two that drift apart. It owns the IR and the topological sort, and depends
on neither `build` nor the plugin API.

**Project invariant:** generated code may only use the public API of `cobalt`. The moment generation
needs something Manual Mode cannot express, these are two frameworks sharing a name.

### Observability is typed events

`CobaltObserver` reports what the graph does — scopes appearing, instances being built, startup
finishing, teardown failing. Callbacks receive descriptions rather than live objects, because an
observer that could resolve from a scope halfway through teardown is not watching any more, and an
exception from a callback is swallowed: watching must not break what it watches.

Records carry `kind` as a value, not a sentence, which is what lets a structured intake key on
`CobaltEventKind.scopeInitFailed` without parsing prose. Log sinks are one callback, so no logger is
locked out for want of an adapter package; crash reporting has a shape of its own, because what makes
a report actionable is the trail of what the graph was doing beforehand.

With no observers registered, the cost of every event is one empty-list check.

### Navigation flows

`cobalt_go_router` makes a scope's lifetime a navigation flow: created when the flow opens, disposed
when it closes. It is an ordinary `ShellRoute` subclass, and the scope is owned by a widget inside
it — nothing watches the router and mirrors it, because mirroring is where hand-rolled versions break
on the back button, on deep links and on tab switches.

A flow of top-level routes with no shared path — `/cart`, `/checkout`, `/payment` — is one shell
too: a `ShellRoute` has no path of its own, so the URLs stay as declared. What stays out of reach is a
route shared by two flows and a boundary decided at run time rather than by the route table; see the
package README.

## Examples

One app runs them all:

```bash
cd examples/gallery && flutter run
```

The gallery is organised by **capability**, not by project — a reader arrives wanting to know how
scopes end, not wanting to see `notes_app`. Seventeen entries in six sections:

| Section | Entries |
|---|---|
| Startup | Two-phase startup · Environments · Lazy async · Async transient |
| Injection | Property injection · Named and multi-injection · Decorators |
| Scopes & lifetime | Widget-owned scope · Session scope · Scope tree · Navigation flows · Teardown |
| Code generation | Generated container · Manual mode |
| Observability | Graph events · In-app inspector |
| Testing | Testing patterns |

Each entry that has a UI opens with a graph **of its own**, built when you open it and disposed when
you leave. Open two and their scope trees are unrelated — which is the thing the gallery is really
there to show. The three entries with no UI (`Teardown`, `Manual mode`, `Testing patterns`) show
their console output instead of a button, because a gallery that offered to "open" a CLI would be
lying.

The gallery is written in English, Russian, Chinese and Korean, switchable from the hub — and so is every
screen it mounts. Each example package carries its own `l10n/*.arb` and generates its own delegate,
which the gallery collects beside its own and the inspector's; that is what a multi-package Flutter
app looks like.

The framework's own log records are still English, as are the identifiers on screen — step names,
scope names, registration keys, lifetimes. See the
[`cobalt_inspector` README](../packages/cobalt_inspector/README.md) for what stays in Cobalt's own words
and why, and the [gallery's](../examples/gallery/README.md) for how the examples are wired.

The eighteen rules of the lint plugin are listed in the
[`cobalt_lint` README](../packages/cobalt_lint/README.md).
