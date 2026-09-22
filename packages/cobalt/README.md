<p align="center">
  <img src="https://raw.githubusercontent.com/rutikeyone/cobalt/main/assets/banner.png" alt="Cobalt — dependency injection for Dart and Flutter" width="880">
</p>

<p align="center">
  <a href="https://pub.dev/packages/cobalt"><img src="https://img.shields.io/pub/v/cobalt?logo=dart&logoColor=white&label=pub&color=5FD4C8" alt="pub package"></a>
  <a href="https://pub.dev/packages/cobalt/score"><img src="https://img.shields.io/pub/points/cobalt?color=5FD4C8" alt="pub points"></a>
  <a href="https://github.com/rutikeyone/cobalt/actions/workflows/ci.yml"><img src="https://github.com/rutikeyone/cobalt/actions/workflows/ci.yml/badge.svg" alt="ci"></a>
  <a href="https://github.com/rutikeyone/cobalt/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="licence"></a>
</p>

# cobalt

Runtime core of [Cobalt](https://github.com/rutikeyone/cobalt), a dependency injection framework for
Dart and Flutter. Pure Dart — it has no Flutter dependency, so the same graph runs in tests, CLIs
and servers. For widgets, add `cobalt_flutter`.

Cobalt works with or without code generation. The generator writes exactly what you would write by
hand, using only the public API of this package.

```dart
final scope = CobaltScope.root(name: 'app')
  ..registerLazySingleton<Logger>(const LoggerFactory())
  ..registerAsyncSingleton<Database>(const DatabaseFactory())
  ..registerAsyncSingleton<SearchIndex>(
    const SearchIndexFactory(),
    dependsOn: {const CobaltKey(Database)},
  );

await scope.init();
final index = scope.get<SearchIndex>();
await scope.dispose();
```

`SearchIndex` states `dependsOn` because both it and `Database` are built during `init()` and one
has to finish first. `Logger` needs no such line: a factory that wants it simply resolves it.

## Quick start

Both modes build the same graph over the same runtime. Pick one per project, or
mix them while you migrate.

**By hand** — no build step, nothing generated:

```dart
import 'package:cobalt/cobalt.dart';

class Clock {
  DateTime now() => DateTime.now();
}

class ClockFactory implements CobaltFactory<Clock> {
  const ClockFactory();

  @override
  Clock create(CobaltResolver resolver) => Clock();
}

class AppScope implements CobaltScopeBuilder {
  const AppScope();

  @override
  void build(CobaltScope scope) {
    scope.registerLazySingleton<Clock>(const ClockFactory());
  }
}

Future<void> main() async {
  final app = await CobaltApplication.start(root: const AppScope());

  print(app.get<Clock>().now());

  await app.dispose();
}
```

**Generated** — the same graph, written for you by `build_runner`:

```dart
import 'package:cobalt/cobalt.dart';
import 'package:cobalt_annotations/cobalt_annotations.dart';

@cobaltInject
class Clock {
  DateTime now() => DateTime.now();
}

@CobaltScopeRoot(name: 'app')
class AppScope {
  const AppScope();
}
```

```bash
dart run build_runner build
```

That writes `lib/cobalt.g.dart`, and `await $startCobalt()` gives you the same
scope the hand-written version built.

Full walkthroughs: [Manual Mode](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_MANUAL.md)
and [Code-Gen Mode](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_CODEGEN.md).

## What it guarantees

- **Hierarchical scopes.** `scope.push('session')` creates a child that sees its parent and can
  shadow it. Parents never resolve downwards.
- **Deterministic teardown.** A scope disposes its children first, then its own instances in
  reverse *creation* order — not registration order, so an object is always torn down before what
  it depends on. Teardown is best-effort under a deadline covering the whole
  tree (30s by default): a step that throws or runs past the deadline is recorded and the remaining
  steps still run, so one broken object cannot strand everything after it. The scope always reaches
  `disposed`; `CobaltDisposeError` is then thrown listing every failure, with `hasTimeout` telling
  overruns from thrown errors.

  A failed `init()` is the one thing that does not count as a teardown failure: the error already
  went to whoever called `init()`, so `dispose()` records it as context — visible through
  `initFailures`, and only reported when teardown itself also broke. An init that *hangs* is
  different, since finishing that wait is teardown's own work, and it is reported like any other
  overrun.
- **Async init as a graph.** `dependsOn` is topologically sorted into levels; each level runs
  through `Future.wait`, so independent branches start together. It waits only for another async
  registration — naming a plain one fails `init()` rather than being dropped, because a
  registration with no async build has nothing to finish. An async registration in an *ancestor*
  is the exception and is ignored: a parent's phase 1 is its own, and a child pushed onto a live
  parent finds it already built.
- **Cycles fail loudly.** Both the init graph and runtime resolution raise `CobaltCycleError`
  naming the path, rather than deadlocking or overflowing the stack.
- **No closures in registrations.** Factories are objects (`CobaltFactory`, `CobaltAsyncFactory`,
  `CobaltParamFactory`), so generated code can be `const`.
- **The graph can report itself.** `CobaltObserver` sees scopes appear, instances get built,
  startup finish and teardown fail. Callbacks receive descriptions (`CobaltScopeRef`, `CobaltKey`)
  rather than live objects, and an exception thrown from one is swallowed — watching must not break
  what it watches. `CobaltLogObserver` plus `CobaltDeveloperLogSink` is the zero-dependency default;
  `cobalt_talker`, `cobalt_logging` and `cobalt_logger` connect real loggers.

  ```dart
  final scope = await CobaltApplication.start(
    root: const AppScope(),
    observers: [CobaltLogObserver(const CobaltDeveloperLogSink())],
  );
  ```

  Any logger works without an adapter, because a sink is one callback:

  ```dart
  CobaltLogObserver(CobaltLogSink.from((record) => myLogger.debug(record.message)))
  ```

  `CobaltMultiSink` fans a record out to several destinations, and a sink that throws does not
  silence the others. With no observers registered, each event costs one empty-list check.
- **Environments are optional, and a plain guard when used.** A graph has one environment until you
  split it. `CobaltEnvironment.matches` then decides whether a registration restricted to some names
  belongs to this build, so selecting an implementation per environment is one `if` around a
  `register*` call and reads the same whether you wrote it or the generator did:

  ```dart
  if (environment.matches(const {'dev', 'test'})) {
    scope.registerLazySingleton<ApiClient>(const FakeApiClientFactory());
  }
  ```

  `dev`, `stage`, `prod` and `test` are constants rather than a closed set, and subclassing
  `CobaltEnvironment` to override `matches` activates several at once.
- **Nothing outlives the scope by accident.** Bootstrap steps run before any container exists, so
  they cannot be registered — but the root scope adopts them, and a step holding a resource is
  released with the scope. Adopted first, they are disposed last, after everything built on the
  platform they set up. `scope.adopt(x)` does the same for any object that belongs to a scope's
  lifetime without being a dependency.

Ownership is explicit: a parent holds its children strongly, and whoever creates a scope closes it.
A scope that is dropped without `dispose()` leaks by design — that is the price of a deterministic
teardown order, and it is what makes `dispose()` reliable.

### What ownership does not do

Owning an object is not the same as being the only thing that holds it. `dispose()` runs, the scope
lets go, and the object still lives for as long as anything else points at it — and nothing in a
container can reach into your code and take a reference back.

The case worth naming, because it is the one this framework was written against: something
long-lived that keeps what a short-lived scope handed it.

```dart
// A root-lived hub, and a session object that registers itself with it.
final session = root.push('session');
session.get<SessionState>();   // its constructor calls hub.listen(this)

await session.dispose();       // SessionState.dispose() runs — and the hub still holds it
```

`test/leak_test.dart` pins that behaviour with `leak_tracker`, so it is known rather than
discovered.

The same thing one step further in: an object that *holds* something closeable and offers no way to
close it. A `StreamSubscription` in a field, no `dispose()` anywhere. The scope retains only what
says how to close, so it never retains this at all — the object is built, the subscription runs, and
the logout that was supposed to end it does not. Five session scopes measured that way left five
live listeners. `cobalt_resource_is_never_closed` reports it before it ships, because the runtime
cannot: guessing at a `cancel()` by name would cancel the ones that only look closeable.

Migrating an application that already fans out state changes to nine listeners is exactly where this
bites. The point of a session scope is that those subscriptions **go away** — you stop listening for
a logout and let the scope end instead. Carrying them across unchanged keeps the leak and adds a
scope that looks like it solved it.

## Closing what the scope cannot recognise

A scope tears down what it built, in reverse creation order, by looking for
`Disposable` or `AsyncDisposable`. A type from another package implements
neither, so it says nothing about how to close — pass `dispose` and the scope
calls it at teardown, in the same order as everything else:

```dart
scope.registerLazySingleton<http.Client>(
  const ClientFactory(),
  dispose: (client) => client.close(),
);

scope.adopt(controller, dispose: (it) => it.close());
```

It is available on every registration the scope retains — `registerSingleton`,
`registerLazySingleton`, `registerAsyncSingleton` and `adopt`. It is deliberately
**not** on `registerFactory` or `registerParamFactory`: a transient is not
retained, so a callback there could never run, and a signature that accepts one
would be lying.

For a class you own, implement `Disposable` instead. Keeping the knowledge on
the object rather than at each registration means it cannot be forgotten at one
of them.

## Optional dependencies

`scope.getOrNull<T>()` returns null when nothing is registered for `T`, instead of throwing. It is
what a nullable dependency reads: in Code-Gen Mode a `Foo?` parameter or `@injected` field is
emitted as `getOrNull`, so a graph that supplies nothing injects null.

Null means one thing only — nothing is registered under that key. An async singleton asked for
before `init()` still throws `CobaltNotReadyError`, and a parameterized factory still throws.
Folding those into null would turn a startup-ordering bug into a value that reads as "absent".

## Inspecting a scope

Four read-only members, for diagnostics and tests:

| Member | Answers |
|---|---|
| `keys` | what this scope registers, in registration order |
| `visibleKeys` | every key resolvable from here, mapped to the scope that owns it |
| `root` | the outermost scope above this one |
| `debugDescribeTree()` | the subtree as text, one line per scope |

`visibleKeys` is a map rather than a set because the owner is the interesting part: a factory runs
on the scope that owns *its* registration, not the scope you asked from, so a key alone cannot tell
you what an override will reach.

None of them throws on a scope that is being torn down, so a diagnostics screen keeps working
during teardown.

What they deliberately do not tell you:

- **Declared, not built.** A lazy singleton nobody resolved looks exactly like one that is built.
- **Not what teardown will release.** Objects handed to `adopt` have no key at all.
- **Not a count of instances.** One key can stand for any number of live transients, or none.
- **Nothing after `dispose`.** The registrations are cleared, not kept as a tombstone.
- **Not a dependency graph.** A factory never declares what it will ask for.

## Deferring expensive async construction

`registerAsyncSingleton` participates in phase 1, so when `CobaltApplication.start` returns the
whole async graph is up — that is the guarantee the two-phase start exists to give. There are two
ways to keep something expensive out of it, and they answer different questions.

**When it belongs to a feature, defer by lifetime.** Put it in a child scope and push that scope when
the feature is entered:

```dart
final session = root.push('session')
  ..registerAsyncSingleton<Telemetry>(const TelemetryFactory());
await session.init();
```

Startup never sees it, `init()` builds it when it is actually wanted, and closing the feature
disposes it. In Flutter `CobaltScopeWidget` does all of that declaratively and shows `loading` while
`init()` runs. `examples/graph_events` does it by hand, `examples/flow_scopes` through the widget.

**When it lives as long as the app but few screens want it, defer by laziness.** A child scope would
blur who owns it; register it lazily instead, and the first `getAsync` builds it:

```dart
root.registerLazyAsyncSingleton<SearchEngine>(const SearchEngineFactory());

final engine = await root.getAsync<SearchEngine>();
```

It is retained and released like any singleton, in creation order. Concurrent calls share one build;
a failed build is not remembered, so the next call retries. `get` before it is built throws
`CobaltLazyAsyncError`, a lazy build that comes back to its own key throws `CobaltCycleError` with
the path instead of hanging, and `dispose` waits for a build in flight — one that finishes after
the deadline is closed as soon as it arrives. An async singleton cannot name a lazy one in its
`dependsOn`. In Flutter, `CobaltAsyncBuilder` is the widget side of this.

## One graph per isolate

Cobalt is single-threaded by construction. There are no locks anywhere in the
runtime, and `CobaltResolutionTracker` — the cycle detector — is one object
shared by a whole scope tree. Nothing here is safe to touch from two isolates
at once.

In practice that is not a restriction, because a scope cannot cross an isolate
boundary anyway: it holds live objects, and only sendable values cross. So the
rule is simply that each isolate builds its own graph.

If you offload work with `Isolate.run` or `compute`, pass the *data* the work
needs, not the scope or anything resolved from it.

## What resolution costs

Measured rather than asserted, on a graph shaped like the production apps this framework was written
for — 205 registrations in one scope, five of them implementations of one interface. Run it with
`dart run benchmark/resolve_benchmark.dart`.

| | µs per call |
|---|---|
| `get<T>()`, cache hit in the same scope | 0.05 |
| `get<T>()`, four scopes up | 0.12 |
| `isRegistered<T>()` | 0.03 |
| `getAll<T>()`, 5 matches among 205 | 1.4 |

`get` is a map lookup per scope on the way up, so it costs the depth of the tree and nothing else.
`getAll` is the one that scales with the *size* of a scope rather than with what it returns: it has
to look at every registration to find the ones of a type, which measured 1.5 µs at 55 registrations,
1.4 at 205 and 17.7 at 2005. That is linear and nowhere near mattering for the way multi-injection
is used — a handful of calls per screen — so it is documented rather than indexed. Indexing by type
would buy microseconds and cost a second structure to keep correct through shadowing.

The benchmark is not in CI: on a shared runner the numbers say more about the runner than about the
code.

## Several runtime arguments

`registerParamFactory` takes one parameter, and a record is how several become one. Use the **named**
form — it keeps the argument names at both ends, so the call site reads like the constructor it
replaced rather than like a tuple:

```dart
typedef EditorArgs = ({int id, String title, bool draft});

scope.registerParamFactory<Editor, EditorArgs>(const EditorFactory());
scope.getWithParam<Editor, EditorArgs>((id: 42, title: 'card', draft: true));
```

Only the values the container cannot know travel in the record; dependencies still come from the
resolver. That matters more than it looks at first: a screen-scoped controller in a real app is
handed an id and a couple of flags, and takes its repositories from the graph — so the record has
three fields where the hand-written factory had eight parameters.

Positional records work as well, and are fine for two values. Past that the names earn their keep.

## Watching one subtree

Observers are fixed when a scope is built, and inherited by its children. `push` takes its own, so
a screen or a session can be watched without installing anything at startup:

```dart
final session = root.push('session', observers: [CobaltLogObserver(sink)]);
```

They are added to the inherited ones rather than replacing them, they see this scope and everything
below it and nothing beside it, and the first event they get is the push that installed them.

## When an async registration has to be made

`init()` collects the async registrations it finds when it starts, and runs once — its future is
memoized, so calling it again does not pick up anything added since. An async registration made at
or after that moment could therefore never be built, and asking for it would throw for the rest of
the scope's life. So it is refused at the point it is made:

```
Scope "app" is CobaltScopeState.active, so Database would never be built: init() takes the async
registrations it finds when it starts, and runs once. Register it before init(), or push a child
scope and initialize that.
```

The way out the message names is the ordinary one: a child scope has its own phase 1, so
`parent.push('session')`, register, `await child.init()`. Sync registrations are unaffected at any
point — they are built on demand and have no phase to miss.

## What a failed resolve tells you

A resolution that fails inside a factory names the trail that led to it, not only the key that was
missing:

```
Config is not registered in scope "app" or its ancestors. Resolving: Api -> Repository -> Config.
```

`Api` is where you start looking; `Config` alone would leave you grepping. Both
`CobaltNotRegisteredError` and `CobaltNotReadyError` carry it, as prose and as `resolving` — a list of
keys, so a report can be built from it rather than parsed out of the message.

The trail is the synchronous chain of factories on the stack. Asking from the top adds nothing,
because nothing asked. And it stops at an `await`: `Future.wait` enters every registration of an
init level before any of them suspends, so during phase 1 several branches are under construction
at once and none of them called the others. Reading that as a chain would name a caller that never
called, so an awaited build contributes nothing to the trail. The cost is a shorter trail, never a
wrong one.

## Reporting failures

`CobaltObserver` reports everything; `CobaltErrorObserver` reports only what went wrong, and brings
the events that led up to it:

```dart
final scope = await CobaltApplication.start(
  root: const AppScope(),
  observers: [CobaltErrorObserver(CobaltErrorSink.from(myReporter.capture))],
);
```

An `CobaltErrorReport` is the failing record plus its breadcrumbs, oldest first. The exception alone
says a teardown threw; the breadcrumbs say which scope had just been pushed and what it had built
by then, which is usually the part that makes the report actionable. `toStructured()` hands the
whole thing over as a map for a destination that takes structured input.

The trail is a bounded ring — 20 by default — kept at every level, including the per-instance
records `CobaltLogObserver` drops. They cost nothing until something fails.

Reports fire at `error` and above. A teardown failure arrives as a warning: it does mean a resource
leaked, but paging a paid service on every hiccup is how reports stop being read, so lowering that
is a deliberate `reportAt: CobaltLogLevel.warning`.

Only Cobalt's own failures are reported — an initializer that threw, a bootstrap step that failed, a
teardown that could not finish. There is no method for reporting an arbitrary error: this is not a
general error channel.
