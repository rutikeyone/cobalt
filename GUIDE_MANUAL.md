<p align="center">
  <a href="GUIDE_MANUAL.md">English</a> · <a href="GUIDE_MANUAL.ru.md">Русский</a> · <a href="GUIDE_MANUAL.zh-CN.md">中文</a>
</p>

# Manual Mode

Cobalt without code generation: no annotations, no `build_runner`, nothing generated and nothing to
commit. You write the registrations, and the runtime is the same one the generator targets.

This is the whole framework, not a reduced version of it. Everything the generator emits is written
in terms of what this document describes, which is the project's standing invariant — the moment
generation needs something Manual Mode cannot express, they are two frameworks sharing a name.

Reach for this mode when you are migrating an existing container gradually, when the graph is small
enough that a build step is not worth it, or when you are in a package that cannot take a build step
at all. When you want the graph checked at build time instead of at run time, read
[GUIDE_CODEGEN.md](GUIDE_CODEGEN.md) — the two compose in one graph, so this is not a decision you
are locked into.

---

## Contents

1. [Install](#1-install)
2. [Your first graph](#2-your-first-graph)
3. [Registering and reading](#3-registering-and-reading)
4. [Starting a Flutter app](#4-starting-a-flutter-app)
5. [Reading from the graph in a widget](#5-reading-from-the-graph-in-a-widget)
6. [Scopes that end before the app does](#6-scopes-that-end-before-the-app-does)
7. [Closing what you registered](#7-closing-what-you-registered)
8. [Work that has to finish before the app starts](#8-work-that-has-to-finish-before-the-app-starts)
9. [Values that come from the call site](#9-values-that-come-from-the-call-site)
10. [Optional dependencies](#10-optional-dependencies)
11. [One graph, several builds](#11-one-graph-several-builds)
12. [Watching the graph](#12-watching-the-graph)
13. [Tests](#13-tests)
14. [Mistakes worth knowing about in advance](#14-mistakes-worth-knowing-about-in-advance)
15. [When to add the generator](#15-when-to-add-the-generator)

---

## 1. Install

One dependency for a pure-Dart program — a CLI, a server, a package with no widgets:

```yaml
environment:
  sdk: ^3.10.0

dependencies:
  cobalt: ^0.2.0
```

A Flutter app adds the bindings, which re-export the whole runtime, so you never import both:

```yaml
environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  cobalt: ^0.2.0
  cobalt_flutter: ^0.2.0

dev_dependencies:
  cobalt_test: ^0.2.0
  cobalt_test_flutter: ^0.2.0
```

**Nothing here is a dead end.** The floor is Dart `^3.10.0` / Flutter `>=3.38.0`, the same one
[GUIDE_CODEGEN.md](GUIDE_CODEGEN.md) asks for, so adding the generator later is a choice rather
than an upgrade — see [§15](#15-when-to-add-the-generator) for how the two compose.

Optional, and only if you want them: `cobalt_go_router` for a scope per navigation flow, `cobalt_bloc`
so a scope can close a bloc, `cobalt_inspector` to see the graph while the app runs, and one of
`cobalt_talker` / `cobalt_logging` / `cobalt_logger` for observability.

Nothing here needs `cobalt_generator`, `build_runner` or `cobalt_lint`. Those belong to the other mode.

---

## 2. Your first graph

Three pieces: the classes, a factory per class, and a builder that registers them.

```dart
import 'package:cobalt/cobalt.dart';

class Clock {
  DateTime now() => DateTime.now();
}

class EventLog implements Disposable {
  final entries = <String>[];

  void add(String entry) => entries.add(entry);

  @override
  void dispose() => entries.clear();
}
```

A **factory** is an object rather than a closure. That is what lets it be `const`, hold no captured
state, and be shared between every start of the graph — a closure would capture whatever was in
scope where you wrote it, which is the bug that makes a second start reuse the first one's objects.

```dart
class ClockFactory implements CobaltFactory<Clock> {
  const ClockFactory();

  @override
  Clock create(CobaltResolver resolver) => Clock();
}

class EventLogFactory implements CobaltFactory<EventLog> {
  const EventLogFactory();

  @override
  EventLog create(CobaltResolver resolver) => EventLog();
}
```

Dependencies are resolved inside `create`, from the resolver you are handed:

```dart
class ReportFactory implements CobaltFactory<Report> {
  const ReportFactory();

  @override
  Report create(CobaltResolver resolver) =>
      Report(resolver.get<Clock>(), resolver.get<EventLog>());
}
```

A **scope builder** says what a scope holds. It only registers; it never resolves — resolving during
`build` would read a graph that is still being described.

```dart
class AppScope implements CobaltScopeBuilder {
  const AppScope();

  @override
  void build(CobaltScope scope) {
    scope
      ..registerLazySingleton<Clock>(const ClockFactory())
      ..registerLazySingleton<EventLog>(const EventLogFactory())
      ..registerLazySingleton<Report>(const ReportFactory());
  }
}

Future<void> main() async {
  final app = await CobaltApplication.start(root: const AppScope(), rootName: 'app');

  app.get<EventLog>().add('started at ${app.get<Clock>().now()}');

  await app.dispose();
}
```

Registration order does not matter. `Report` may be registered before `Clock`: nothing is built
during `build`, and by the time anything resolves, every registration exists.

There is no global container. `CobaltApplication.start` hands you the root and nothing is ambient, so
two graphs in one process are unrelated and tests can run in parallel.

`examples/manual_mode` is this, complete and runnable:

```bash
cd examples/manual_mode && dart run
```

---

## 3. Registering and reading

### Seven ways to register

| Call | Built | Held by the scope |
|---|---|---|
| `registerSingleton<T>(value)` | already, by you | yes |
| `registerEagerSingleton<T>(factory)` | now, by the scope | yes |
| `registerLazySingleton<T>(factory)` | on first resolve | yes |
| `registerAsyncSingleton<T>(factory)` | during `init()`, in dependency order | yes |
| `registerLazyAsyncSingleton<T>(factory)` | on the first `getAsync` | yes |
| `registerFactory<T>(factory)` | on every resolve | no |
| `registerParamFactory<T, P>(factory)` | on every resolve, from an argument | no |

"Held" is the whole distinction, and it decides teardown: a scope releases what it holds, and a
transient is nobody's to release — see [§7](#7-closing-what-you-registered).

A `name` qualifier makes a second registration of the same type legal, because the key is the type
*and* the name:

```dart
scope
  ..registerLazySingleton<Logger>(const AppLoggerFactory())
  ..registerLazySingleton<Logger>(const AuditLoggerFactory(), name: 'audit');
```

Registering the same key twice in one scope throws. Two things replace a registration without that:
an override handed to the scope that owns the key, and a registration in a child scope that shadows
it for what resolves below — see [§13](#13-tests).

### Six ways to read

```dart
scope.get<Repository>();                       // throws when nothing is registered
scope.getOrNull<Telemetry>();                  // null instead — see §10
scope.get<Logger>(name: 'audit');              // a named registration
scope.getAll<NoteFormatter>();                 // every registration of the type, nearest scope first
scope.getWithParam<Counter, String>('alice');  // a parameterized one
await scope.getAsync<SearchEngine>();          // builds a lazy async one first — see §8
```

`isRegistered<T>()` answers without building anything.

Resolution walks up: this scope, then its parent, and so on to the root. `getAll` collects from the
whole chain, nearest first, and takes a shadowed key only once — from the closest scope that has it.

### Looking at what a scope holds

Diagnostics, and none of it builds anything:

```dart
scope.keys;                  // this scope's own registrations, in registration order
scope.visibleKeys;           // those plus inherited ones, mapped to the scope that owns each
scope.root;                  // the top of the tree
scope.debugDescribeTree();   // the tree as text
```

`visibleKeys` is a map rather than a set for a reason worth internalising early: a factory runs on
the scope that owns *its own* registration, not on the one you asked. Knowing which scope owns a key
is what tells you whether an override will be seen — see [§13](#13-tests).

---

### Wrapping a registration

A decorator wraps what a registration hands out without touching its class — logging, retries, a
cache, a metric around a client you do not own:

```dart
class LoggingApi implements CobaltDecorator<ApiClient> {
  const LoggingApi();

  @override
  ApiClient decorate(ApiClient inner, CobaltResolver resolver) =>
      LoggedApiClient(inner, resolver.get<Logger>());
}

scope
  ..registerLazySingleton<ApiClient>(const ApiClientFactory())
  ..decorate<ApiClient>(const LoggingApi());
```

Decorators apply in the order they are added, the first innermost, and see the resolver of the scope
that owns the registration. A retained registration is decorated once, the first time it is
resolved, and everyone shares the result; a transient or parameterized one is decorated each time it
is built. Where `decorate` sits relative to the registration inside `build()` does not matter, and an
override is decorated like the registration it replaced.

The scope keeps owning the inner instance and closes it once; a decorator holds nothing to close.
Three mistakes are refused: decorating a key already resolved (its holders would keep the undecorated
instance), decorating a key the scope does not register — `runBuilder` names the ancestor that owns
it — and a decorator that resolves its own key, which is a `CobaltCycleError`.

## 4. Starting a Flutter app

`CobaltAppScope` owns the root: it builds the graph, publishes it to the tree, disposes it on unmount,
and turns a failed start into a screen with a retry rather than an app that dies before its first
frame.

Put it in `MaterialApp.builder`, not above `MaterialApp`. There it sits below `Theme`,
`Directionality` and `Localizations`, so `loading` and `errorBuilder` are ordinary screens instead of
a second `MaterialApp`:

```dart
void main() => runApp(
  MaterialApp(
    theme: appTheme,
    builder: CobaltAppScope.builder(
      root: const AppScope(),
      bootstrap: () => [const BindPlatform()],
      rootName: 'app',
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: (context, error, retry) => StartupFailed(error: error, retry: retry),
    ),
    home: const HomeScreen(),
  ),
);
```

`bootstrap` is a function rather than a list on purpose: steps hold resources, and a restart has to
get new ones. A stored list would quietly hand the same objects to the second start.

`CobaltAppScope.of(context).restart()` rebuilds the graph — the same call retries a failed start.

If your app already has a `builder`, compose them yourself rather than expecting the framework to
merge two:

```dart
builder: (context, child) => CobaltAppScope(
  root: const AppScope(),
  child: myWrapper(child!),
),
```

---

**Order inside `build()` matters for eager registrations and not for lazy ones.** A
`registerLazySingleton` is a promise to build later, so it does not care what is registered above or
below it. A `registerSingleton` builds *now*, and anything it resolves has to be registered already.
Composing a hand-written builder on top of a generated one is where this shows up — put the eager
ones after the container, or make them lazy.

## 5. Reading from the graph in a widget

```dart
final repository = context.cobalt<Repository>();
final formatters = context.cobaltAll<NoteFormatter>();
final counter = context.cobaltWithParam<Counter, String>('alice');
final scope = context.cobaltScope;
```

Each resolves from the **nearest** scope above the widget and walks up from there, so a registration
in a flow or session scope shadows the root one for everything inside it.

One thing to know before it bites: `Navigator.push` builds the new route from the navigator's
context, not from the widget that pushed it. A screen that resolves fine when mounted in place will
throw `CobaltNoScopeError` when the same widget is pushed, if the provider it was reading lives
*inside* the pushing screen. Pass the scope explicitly in that case, or push below the provider.

---

## 6. Scopes that end before the app does

This is what the framework is for. A scope is a node in a tree, it owns what it builds, and disposing
it takes everything below it with it.

### A session

```dart
class SessionManager {
  SessionManager(this._root);

  final CobaltScope _root;
  CobaltScope? _session;

  Future<void> signIn(User user) async {
    _session = _root.push('session:${user.id}')
      ..registerLazySingleton<Draft>(const DraftFactory())
      ..registerLazySingleton<SyncQueue>(const SyncQueueFactory());
    await _session!.init();
  }

  Future<void> signOut() async {
    await _session?.dispose();
    _session = null;
  }
}
```

Logout is `await scope.dispose()`. No repository subscribes to a session stream, and no domain
interface grows a `reset()` method it did not want.

`push` returns the child immediately; `init()` runs its async registrations. Call `init()` even when
there are none — it is cheap, idempotent, and means adding an async registration later does not
change the call site.

### A screen

```dart
CobaltScopeWidget(
  name: 'editor',
  builder: const EditorScope(),
  child: const EditorBody(),
)
```

Created when the widget mounts, disposed when it unmounts. Note that the scope is published only
after `init()` completes, so even a fully synchronous graph renders one `loading` frame.

### A navigation flow

With `cobalt_go_router`, the lifetime is the flow rather than a widget you remembered to place:

```dart
class OrderFlowRoute extends CobaltShellRoute {
  OrderFlowRoute()
    : super(
        name: 'order',
        identity: _orderId,
        scope: (state) => OrderFlowScope(_orderId(state)),
        routes: [
          GoRoute(
            path: '/orders/:orderId/summary',
            builder: (_, state) => OrderSummaryScreen(orderId: _orderId(state)),
          ),
          GoRoute(
            path: '/orders/:orderId/payment',
            builder: (_, state) => OrderPaymentScreen(orderId: _orderId(state)),
          ),
        ],
      );

  static String _orderId(GoRouterState state) => state.pathParameters['orderId']!;
}

class OrderFlowScope implements CobaltScopeBuilder {
  const OrderFlowScope(this.orderId);

  final String orderId;

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<OrderDraft>(OrderDraftFactory(orderId));
}
```

Note that `OrderDraftFactory` is not `const` here: it carries the order id. A factory that takes
configuration is fine; what it must not do is capture the surrounding graph.

Navigating between `summary` and `payment` keeps one scope. Leaving the flow disposes it. `identity`
answers the one question the router cannot: whether `/orders/1` and `/orders/2` are the same flow.

Build the route table **once**, alongside the router. A new `CobaltShellRoute` instance is a different
flow as far as go_router is concerned, so rebuilding the list every frame would rebuild the scope
every frame.

Tabs work the same way with `CobaltStatefulShellRoute` and `CobaltStatefulShellBranch`, with one
behaviour worth stating plainly: a branch is kept **alive**, not kept **visible**. go_router
preserves branch navigators off-screen, so a tab's scope lives until the shell closes, not until you
switch away.

---

## 7. Closing what you registered

A scope releases what it holds, in reverse **creation** order — not declaration order, which is the
bug hand-written containers have: a component declared first but created last is destroyed first,
while something still depends on it.

Dart has no structural typing, so a matching `dispose()` method is not enough on its own. Say which
interface it is:

```dart
class Cache implements Disposable {
  @override
  void dispose() { ... }
}

class Database implements AsyncDisposable {
  @override
  Future<void> dispose() async { ... }
}
```

For a type you cannot change — from the SDK, from another package, behind a base class — name the
teardown at the registration:

```dart
scope.registerLazySingleton<http.Client>(
  const ClientFactory(),
  dispose: (client) => client.close(),
);

scope.registerAsyncSingleton<Isar>(
  const IsarFactory(),
  dispose: (isar) => isar.close(),
);
```

`dispose:` exists only on registrations the scope holds. `registerFactory` and `registerParamFactory`
do not take it, because a transient is not the scope's to close — the case is unrepresentable rather
than checked at runtime. If a transient owns something, its consumer owns it too.

### Flutter types that look closable and are not

`ChangeNotifier.dispose` matches `Disposable.dispose` exactly, and is still invisible to the scope,
because Dart matches interfaces by name and not by shape. Say so:

```dart
class Filters extends ChangeNotifier implements Disposable {}
```

For blocs, `cobalt_bloc` is the one line:

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);
}
```

or, where a mixin will not reach, `dispose: closeBloc` at the registration.

Then hand it to the widget tree with `BlocProvider.value`, never `BlocProvider(create:)` — the latter
closes what it was given when it unmounts, while the scope still holds it and will hand out the dead
object on the next resolve.

### When teardown goes wrong

It is best-effort by design. A step that throws is recorded and the rest still run; the whole tree
has one deadline; and the scope always reaches `disposed`. What did not finish is listed in
`CobaltDisposeError` — `failures`, `timeouts`, `hasTimeout` — instead of the first failure hiding the
other nine.

`adopt` ties an object to a scope's life without it being a dependency — useful for a subscription or
a timer that nothing resolves:

```dart
scope.adopt(subscription, dispose: (it) => it.cancel());
```

---

## 8. Work that has to finish before the app starts

Two phases, answering different questions.

**Phase 0 — bootstrap steps.** Before the container exists: platform bindings, remote config,
anything the graph itself needs. Steps run strictly in the order you list them, and can inject
nothing, because there is nothing to inject from yet.

```dart
class BindPlatform implements CobaltBootstrapStep {
  const BindPlatform();

  @override
  String get name => 'bind-platform';

  @override
  Future<void> run() async => WidgetsFlutterBinding.ensureInitialized();
}

final app = await CobaltApplication.start(
  root: const AppScope(),
  bootstrap: const [BindPlatform(), LoadRemoteConfig()],
  rootName: 'app',
);
```

Once they have run, the root scope adopts them, so a step that opened something has it closed at
teardown — last, after everything built on top of it. If a step fails, the ones that already ran are
released in reverse before the error is rethrown, since there is no scope yet to hand them to.

**Phase 1 — async singletons.** Inside the container, built in dependency order:

```dart
class DatabaseFactory implements CobaltAsyncFactory<Database> {
  const DatabaseFactory();

  @override
  Future<Database> create(CobaltResolver resolver) async {
    final database = Database(resolver.get<Config>());
    await database.open();
    return database;
  }
}

scope
  ..registerAsyncSingleton<Database>(const DatabaseFactory())
  ..registerAsyncSingleton<SearchIndex>(
    const SearchIndexFactory(),
    dependsOn: {CobaltKey(Database)},
  );
```

`dependsOn` is an ordering edge, not an injection — you still resolve `Database` inside
`SearchIndexFactory.create`. Independent initializers on the same level run together through
`Future.wait`; only what actually depends waits. A cycle throws `CobaltCycleError` naming the path
rather than hanging.

Naming a key that is registered but **not** async is an error, not a no-op: there is no build to
wait for. Naming one that is async in an **ancestor** scope is allowed and ignored — the ancestor ran
its own phase 1 before this scope existed.

`CobaltApplication.start` returns when both phases are done, so there is no `allReady()` to call and no
"registered but not ready" state to reason about.

Async registrations have to exist before `init()` runs. It takes the ones it finds when it starts and
runs once, so registering another into a scope that is already active is an error rather than
something that quietly never gets built. Push a child scope and initialize that instead.

### Built when first asked for

Phase 1 builds everything at startup. For something expensive that lives as long as the app but is
wanted by few screens, that is the wrong trade — register it lazily instead, and nothing is built
until the first `getAsync`:

```dart
scope.registerLazyAsyncSingleton<SearchEngine>(const SearchEngineFactory());

final engine = await scope.getAsync<SearchEngine>();
```

It is held and released with the scope like any other singleton, in the order it was *created*.
Concurrent calls share one build. A build that fails is not remembered: everyone waiting gets the
error, and the next call tries again. It may be registered after `init()`, because it has no phase
to miss.

Reading it synchronously works once it is built. Before that, `get` throws `CobaltLazyAsyncError`
naming `getAsync` — and so does `getAll`, which has `getAllAsync` beside it. A lazy factory can
await another lazy registration through its resolver; a chain that comes back to its own key is a
`CobaltCycleError` with the path, not a hang. An async singleton cannot name a lazy one in its
`dependsOn` — `init()` has nothing to wait for.

`dispose` waits for a build in flight and releases what it made. A build still running past the
deadline is abandoned like any other overrun, and when it does finish its result is closed at once.

In a widget, `CobaltAsyncBuilder` shows `loading` while the first screen builds it, and renders
straight away on every screen after:

```dart
CobaltAsyncBuilder<SearchEngine>(
  loading: const Center(child: CircularProgressIndicator()),
  errorBuilder: (context, error, retry) => RetryView(onRetry: retry),
  builder: (context, engine) => SearchScreen(engine: engine),
)
```


To have it ready before a screen opens, warm it up. `warmUp` starts every build in the list at once,
off the startup path; each is the build `getAsync` would start, so a screen that asks meanwhile waits
for it rather than starting a second:

```dart
unawaited(scope.warmUp(const [CobaltKey(SearchEngine)]));
```

Every key is checked before anything is built, and builds that fail do not stop the others — they
arrive together as a `CobaltWarmUpError`. In Flutter, `CobaltAppScope(warmUp: [...])` does it as soon
as the graph is up, behind the app rather than behind `loading`, and reports a failure to
`FlutterError.reportError`.

---

## 9. Values that come from the call site

Half of an object comes from the graph and half from whoever is building it:

```dart
class CounterFactory implements CobaltParamFactory<Counter, String> {
  const CounterFactory();

  @override
  Counter create(CobaltResolver resolver, String sessionId) =>
      Counter(resolver.get<CounterStorage>(), sessionId);
}

scope.registerParamFactory<Counter, String>(const CounterFactory());

final counter = scope.getWithParam<Counter, String>('alice');
```

There is one parameter. For more than one, bundle them into a record — named, so the call site still
reads:

```dart
typedef EditorArgs = ({int id, String title, bool draft});

class EditorFactory implements CobaltParamFactory<Editor, EditorArgs> {
  const EditorFactory();

  @override
  Editor create(CobaltResolver resolver, EditorArgs args) =>
      Editor(resolver.get<Notes>(), id: args.id, title: args.title, draft: args.draft);
}

scope.getWithParam<Editor, EditorArgs>((id: 7, title: 'draft', draft: true));
```

The parameter type is checked at the call, not inside your factory: passing the wrong type throws
`CobaltParamTypeError` naming the key, the expected type and what arrived. A legal subtype is
accepted, because what is checked is the value rather than the type literal.

Resolving a parameterized registration with plain `get<T>()` throws `CobaltParamRequiredError` — the
argument has nowhere to come from.

---

## 10. Optional dependencies

```dart
class ReportFactory implements CobaltFactory<Report> {
  const ReportFactory();

  @override
  Report create(CobaltResolver resolver) =>
      Report(resolver.get<Clock>(), resolver.getOrNull<Telemetry>());
}
```

`getOrNull` returns null only for "nothing is registered". An async singleton asked for before
`init()` still throws, and so does a parameterized registration asked for without an argument,
because "not ready" and "not there" are different facts — collapsing them turns a startup-order bug
into a value that reads as absence.

---

## 11. One graph, several builds

Skip this until one build genuinely needs a different implementation than another. Until then your
graph has exactly one environment and nothing here applies.

`CobaltEnvironment.matches` is ordinary public API, so the choice is an `if`:

```dart
class AppScope implements CobaltScopeBuilder {
  const AppScope(this.environment);

  final CobaltEnvironment environment;

  @override
  void build(CobaltScope scope) {
    scope.registerLazySingleton<EventLog>(const EventLogFactory());

    if (environment.matches(const {'dev', 'test'})) {
      scope.registerLazySingleton<ApiClient>(const FakeApiClientFactory());
    }
    if (environment.matches(const {'prod', 'stage'})) {
      scope.registerLazySingleton<ApiClient>(const LiveApiClientFactory());
    }
  }
}
```

`dev`, `stage`, `prod` and `test` are constants, not a closed set — `CobaltEnvironment('canary')`
behaves identically. Subclass it and override `matches` to activate several at once, or to match on
something other than the name.

Nothing checks these branches for you here. Two `if`s that are both true register the same key twice
and throw at startup; two that are both false leave the type unregistered and the first resolve
fails saying so. That is the trade of this mode — the other one rejects both at build time.

---

## 12. Watching the graph

Observers see scopes appearing, instances being built, startup finishing, teardown failing. Pass them
where the graph is created; every scope pushed below inherits them.

```dart
final app = await CobaltApplication.start(
  root: const AppScope(),
  observers: [CobaltLogObserver(const CobaltPrintLogSink())],
);
```

`CobaltPrintLogSink` writes to stdout, which is the right default outside an app;
`CobaltDeveloperLogSink` (`dart:developer`) is the one for a Flutter app. `push(name, observers: [...])`
adds more for one subtree.

Callbacks get `CobaltScopeRef` and `CobaltKey` — descriptions, not live objects — and an exception
thrown from one is swallowed: watching must not be able to break what it watches. Resolution is not
reported; a cache hit is the hot path, and what is worth seeing is an instance being *built*.

### Sending it somewhere

| Package | Shape |
|---|---|
| `cobalt_talker` | an observer, one coloured log type per event family |
| `cobalt_logging` | a sink over dart.dev `logging` |
| `cobalt_logger` | a sink over `logger` |

Anything else is one callback, so no logger is locked out for want of a package:

```dart
CobaltLogObserver(CobaltLogSink.from((r) => myLogger.debug(r.message)))
CobaltLogObserver(CobaltLogSink.from((r) => gelf.send(r.toStructured())))
```

The record is not just a string: `level`, `scope`, `key`, `error`, `stackTrace` and `kind` are all
there, and `kind` is a value — `CobaltEventKind.scopeInitFailed` rather than a sentence you would have
to parse.

### Crash reports are a different shape

What makes a report actionable is not the exception; it is what the graph was doing beforehand.

```dart
observers: [
  CobaltErrorObserver(
    CobaltErrorSink.from((report) => Sentry.captureException(
      report.error,
      stackTrace: report.stackTrace,
      withScope: (scope) => scope.setContexts('cobalt', report.toStructured()),
    )),
  ),
],
```

The trail is a ring of 20 records kept at every level, including the per-instance ones a log sink
drops. The threshold is `error`, not `warning` — a teardown failure does mean a leak, but paging a
paid service on every hiccup is how reports stop being read. Lower it with `reportAt`.

### On screen, while the app runs

```dart
final log = CobaltInspectorLog();

// observers: [log]

CobaltInspectorScreen(log: log, scope: context.cobaltScope)
```

Three tabs: the live scope tree with each registration's lifetime and who owns it, what has actually
been built, and everything reported, searchable and pausable. Opening the tree builds nothing —
materialising a lazy singleton to display it would change what you came to look at.

---

## 13. Tests

The first thing to know is a trap, not an API. `testWidgets` runs its body inside a fake-async zone,
where a `Future.delayed` in an initializer never completes. **Build the graph in `setUp`**, and keep
whole-graph assertions in a plain `test`.

```dart
late CobaltScope scope;

setUp(() async {
  scope = await cobaltTestScope(root: const AppScope());
});
```

`cobaltTestScope` and `cobaltTestRoot` dispose with the test, which is the part that is easy to leave
out — and leaving it out leaks into the next test rather than failing.

### Checking the graph is complete

**This matters more here than anywhere else.** A hand-written factory resolves inside `create`, so
nothing static can see what it will ask for: a missing registration is a runtime failure, and it will
surface on whichever screen happens to resolve it first. Running the graph is the only check:

```dart
await expectGraphResolves(scope);
```

It reports every key it could not build, not the first one. It is terminal — resolving *is* the
check, so afterwards every lazy singleton is built and the teardown order is different. Put it in a
test of its own.

A parameterized registration cannot be resolved without a value, so it is reported by name as
`unchecked` rather than skipped in silence — hand it a sample to actually cover it:

```dart
await expectGraphResolves(scope, params: {CobaltKey(Counter): 'alice'});
```

Make this test part of the suite from the first day of a Manual Mode graph. It is what the other mode
gets from the compiler.

### Overriding

Hand the replacement to the scope that owns the key. An override is registered first, when the scope
is created, and the real registration of the same key is then skipped rather than rejected as a
duplicate — so every factory in that scope resolves the replacement:

```dart
final scope = cobaltTestRoot(
  overrides: [CobaltOverride<Clock>.value(FixedClock(DateTime(2026)))],
)..runBuilder(const AppScope());
```

`.value` takes a built object, `.lazy` and `.transient` a factory, and `CobaltParamOverride<T, P>`
a parameterized one. `cobaltTestScope(overrides:)` and `CobaltApplication.start(overrides:)` take
the same list; `CobaltAppScope(overrides: () => [...])` takes a function, called on every start, so
a restart does not get back a value the previous graph already closed. A flavour or a debug menu is
the case in an app.
An override is never silent: observers receive `onRegistrationOverridden`, and `overriddenKeys`
lists what is replaced.

`CobaltScopeWidget`, the scoped widgets and every flow-owning route take `overrides` too, as a
function called each time their scope is created — the way to mount one screen in a widget test with
a double in place. They replace what that scope registers; a key an ancestor owns is overridden on
the ancestor, and asking the child to do it fails naming the owner.

Register an eager singleton with `registerEagerSingleton` when it is expensive to build. A value
handed to `registerSingleton` already exists before the scope can say no, so under an override it is
kept and closed with the scope but never resolved; `registerEagerSingleton` lets the scope build it,
and skip it.

Name the type argument. Inside the list Dart infers it as `Object`, which the scope refuses as soon
as it is created. Written on its own it infers the replacement's type — `FixedClock`, not `Clock` —
and `runBuilder` reports the override that replaced nothing.

Shadowing from a child scope is the other way, and the one production uses for sessions and flows:

```dart
final child = scope.pushForTest()
  ..registerSingleton<Clock>(FixedClock(DateTime(2026)));
```

It reaches only what is resolved from the child: **a factory runs on the scope that owns its own
registration**, so a consumer registered above keeps the real dependency. `ownerOf<T>()` answers
before the test does:

```dart
expect(scope.ownerOf<Greeter>(), same(scope.root));   // owned by the root, so override there
```

### Fixtures

```dart
final scope = cobaltTestRoot()
  ..registerLazySingleton<Clock>(FnFactory((_) => FixedClock(DateTime(2026))))
  ..registerSingleton<Config>(const Config())
  ..registerAsyncSingleton<Db>(AsyncFnFactory((_) async => Db()))
  ..registerParamFactory<Counter, String>(FnParamFactory((_, id) => Counter(id)));

await scope.init();
```

These four save writing a factory class per stub. Async registrations have to exist **before**
`init()`, which is why fixtures go into a fresh root rather than into a scope that has already
started.

`DisposeRecorder` is the fixture for teardown assertions, with a log per instance rather than a
shared one, so a scope disposed after the test that made it cannot report into the next:

```dart
final recorder = DisposeRecorder();
scope.registerLazySingleton<Disposable>(recorder.factory('cache'));
scope.get<Disposable>();

await scope.dispose();
expect(recorder.entries, ['cache']);
```

`CapturingObserver` collects events for assertions about what the graph did.

### Widget tests

`cobalt_test_flutter` carries the two helpers whose obvious spelling is wrong:

```dart
await settle(tester);                    // not pumpAndSettle: it spins forever on a loading indicator
final scope = mountedRootScope(tester);  // the app's graph, from below the MaterialApp builder
```

`examples/testing_patterns` is a package whose whole point is its `test/` directory.

---

## 14. Mistakes worth knowing about in advance

Each of these was found the hard way, in this repository or in the applications it was written for.

- **No `expectGraphResolves` in the suite.** In this mode nothing else checks the graph is complete.
  A missing registration ships and fails on a screen.
- **Building the graph inside `testWidgets`.** Fake-async, no completion, a timeout with nothing to
  point at. `setUp`.
- **Overriding below the consumer.** The factory runs on the owning scope. `ownerOf<T>()` tells you
  before the assertion does.
- **A factory that captures instead of resolving.** Read collaborators from the `resolver` handed to
  `create`, not from variables in scope where the factory was written; otherwise a second start
  reuses the first graph's objects.
- **Resolving inside `CobaltScopeBuilder.build`.** It runs while the scope is still being described.
  Register there; resolve later.
- **`bootstrap` as a stored list** when you own the root through `CobaltAppScope`. Steps hold
  resources; a restart must get new ones. Pass a function.
- **`BlocProvider(create:)` for a bloc the scope owns.** Two owners, and the widget wins first.
  `BlocProvider.value`.
- **A `ChangeNotifier` or `Cubit` registered without saying it is closable.** Built, used, never
  closed, silently. `implements Disposable`, `with CobaltBloc`, or `dispose:`.
- **An old `dart` first on PATH.** It fails quietly and in the wrong place. Check `dart --version`
  before believing a run.

---

## 15. When to add the generator

Nothing here has to be thrown away to do it. The generated container is an `CobaltScopeBuilder` like
the ones above, so it composes with what you already wrote:

```dart
class AppScope implements CobaltScopeBuilder {
  const AppScope();

  @override
  void build(CobaltScope scope) {
    $CobaltRootScope().build(scope);          // what the generator found
    scope.registerSingleton<Config>(config); // what it cannot know about
  }
}
```

Three things are worth the build step when the graph gets big:

- **completeness checked at build time** rather than by `expectGraphResolves` at test time;
- **property injection**, which empties constructors that have grown to five or more collaborators;
- **fourteen lint rules** that catch the mistakes in §14 in the editor.

What stays exactly as it is: scopes, teardown, the two phases, parameterized registrations,
observability, the tests. [GUIDE_CODEGEN.md](GUIDE_CODEGEN.md) picks up from here, and
[MIGRATION.md](MIGRATION.md) covers arriving from `get_it` or `injectable`.
