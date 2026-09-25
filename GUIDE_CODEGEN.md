<p align="center">
  <a href="GUIDE_CODEGEN.md">English</a> · <a href="GUIDE_CODEGEN.ru.md">Русский</a> · <a href="GUIDE_CODEGEN.zh-CN.md">中文</a>
</p>

# Code-Gen Mode

Cobalt with the generator: you annotate the classes, `build_runner` writes the container, and the
graph is checked before it builds. What comes out is ordinary Dart that uses nothing but the public
API of `cobalt` — you can read it, and everything in it could have been written by hand.

That is the project's standing invariant, and it has a practical consequence you will use: the
generated container is an `CobaltScopeBuilder` like any other, so hand-written registrations compose
with it in one graph. Nothing here is all-or-nothing.

What the build step buys you, and what this document is mostly about:

- **the graph checked at build time** — a dependency nothing registers fails the build, naming every
  gap at once, instead of failing on whichever screen resolves it first;
- **property injection** — `late final` fields filled by a generated mixin, so a class with five
  collaborators has an empty constructor;
- **fourteen lint rules** that catch the rest in the editor.

If you want none of that, or you are migrating an existing container gradually, everything works
without the generator: [GUIDE_MANUAL.md](GUIDE_MANUAL.md).

---

## Contents

1. [Install](#1-install)
2. [Your first generated graph](#2-your-first-generated-graph)
3. [What comes out](#3-what-comes-out)
4. [Property injection](#4-property-injection)
5. [The graph has to be complete](#5-the-graph-has-to-be-complete)
6. [Composing on top of the generated root](#6-composing-on-top-of-the-generated-root)
7. [Starting a Flutter app](#7-starting-a-flutter-app)
8. [Reading from the graph in a widget](#8-reading-from-the-graph-in-a-widget)
9. [Scopes that end before the app does](#9-scopes-that-end-before-the-app-does)
10. [Closing what you registered](#10-closing-what-you-registered)
11. [Work that has to finish before the app starts](#11-work-that-has-to-finish-before-the-app-starts)
12. [Values that come from the call site](#12-values-that-come-from-the-call-site)
13. [Optional dependencies](#13-optional-dependencies)
14. [Types you did not write](#14-types-you-did-not-write)
15. [One graph, several builds](#15-one-graph-several-builds)
16. [The lint plugin](#16-the-lint-plugin)
17. [Watching the graph](#17-watching-the-graph)
18. [Tests](#18-tests)
19. [Mistakes worth knowing about in advance](#19-mistakes-worth-knowing-about-in-advance)

---

## 1. Install

The runtime ships to the app; the generator never does.

```yaml
environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  cobalt: ^0.2.0
  cobalt_flutter: ^0.2.0

dev_dependencies:
  cobalt_generator: ^0.2.0
  build_runner: ^2.15.0
  cobalt_lint: ^0.2.0
  cobalt_test: ^0.2.0
  cobalt_test_flutter: ^0.2.0
```

**The floor is the same as the other mode's**, so an application on Flutter 3.38 can start here
rather than starting in [GUIDE_MANUAL.md](GUIDE_MANUAL.md) and migrating.

One thing comes with it: on Flutter 3.38 your project resolves `analyzer 10.0.1` and
`build_runner 2.15.1`, because Flutter pins `meta 1.17.0` there and a newer analyzer wants
`^1.18.0`. On a newer Flutter it resolves 12.1.0 instead, and the generated code is the same either
way. See **Requirements** in the [README](README.md) for the whole row.

A pure-Dart package — a CLI, a server, a package with no widgets — drops `cobalt_flutter` and
`cobalt_test_flutter`. Nothing in the runtime needs Flutter.

The annotations arrive with `cobalt`, which re-exports them, so one import covers both:

```dart
import 'package:cobalt/cobalt.dart';
```

Optional, and only if you want them: `cobalt_go_router`, `cobalt_bloc`, `cobalt_inspector`, and one of
`cobalt_talker` / `cobalt_logging` / `cobalt_logger`.

---

## 2. Your first generated graph

Annotate the classes. Dependencies are constructor parameters, and the generator works out what
resolves what.

```dart
import 'package:cobalt/cobalt.dart';

@cobaltInject
class Config {
  Config();

  final String environment = 'test';
}

@cobaltInject
class Repository {
  Repository(this.config);

  final Config config;
}

@cobaltInject
class Telemetry implements Disposable {
  Telemetry();

  final events = <String>[];

  void record(String event) => events.add(event);

  @override
  void dispose() => events.clear();
}
```

`@cobaltInject` is a lazy singleton — built on first resolve, held by the scope. The other lifetimes
have their own constants, and the long form takes everything else:

| Annotation | Lifetime |
|---|---|
| `@cobaltInject` | lazy singleton |
| `@cobaltSingleton` | eager singleton, built when the graph is built |
| `@cobaltTransient` | a new instance on every resolve, held by nobody |

```dart
@CobaltInject(exposeAs: ApiClient, name: 'live', dispose: closeClient)
class LiveApiClient implements ApiClient { ... }
```

`exposeAs` registers the class under an interface, which is how a consumer depends on `ApiClient`
rather than on the implementation. `name` is a qualifier, so a second registration of the same type
is legal and read with `get<Logger>(name: 'audit')`.

Name the root once, anywhere in the package:

```dart
@CobaltScopeRoot(name: 'app')
class AppScope {
  const AppScope();
}
```

Then generate:

```bash
dart run build_runner build
```

`dart run build_runner watch` while you work. Commit the output: CI regenerates and fails on a diff,
which is how stale generated code gets caught rather than shipped.

**One root per package.** `cobalt_container` aggregates the whole package into a single
`$CobaltRootScope`; two `@CobaltScopeRoot` classes in one package is a generation error. Two
independent generated graphs therefore need two packages — which is exactly why the examples in this
repository are separate packages rather than folders.

---

## 3. What comes out

`lib/cobalt.g.dart`, and it is worth reading once so the mode stops being a black box:

```dart
final class _RepositoryFactory implements CobaltFactory<Repository> {
  const _RepositoryFactory();

  @override
  Repository create(CobaltResolver resolver) => Repository(resolver.get<Config>());
}

final class $CobaltRootScope implements CobaltScopeBuilder {
  const $CobaltRootScope();

  @override
  void build(CobaltScope scope) {
    scope.registerLazySingleton<Config>(const _ConfigFactory());
    scope.registerLazySingleton<Telemetry>(const _TelemetryFactory());
    scope.registerLazySingleton<Repository>(const _RepositoryFactory());
  }
}

const String $cobaltRootScopeName = 'app';

Future<CobaltScope> $startCobalt() => CobaltApplication.start(
  root: const $CobaltRootScope(),
  rootName: $cobaltRootScopeName,
);
```

```dart
final scope = await $startCobalt();
```

Shown without them here for readability, but the real file prefixes every imported name with an
alias derived from a hash of its URL — `_i178.CobaltFactory`. It is a hash rather than a counter so
that adding one import does not renumber all the others and turn a one-line change into a whole-file
diff.

Four things about that output are deliberate:

- **Private const factory classes, not closures.** A `const` factory holds no captured state, so a
  second start cannot reuse the first graph's objects.
- **Registrations in topological order**, worked out at build time. Property-injected fields count as
  edges too, so a bloc is always registered after what it injects.
- **No reflection and no runtime scanning.** Whatever is in that file is the whole graph.
- **`$cobaltBootstrap` is a getter**, not a stored list, so a restart gets fresh steps — see
  [§11](#11-work-that-has-to-finish-before-the-app-starts).

The generator formats its output with the same `dart_style` your format check uses, so the two never
disagree.

---

## 4. Property injection

A class with five collaborators does not need five constructor parameters. Declare the fields and mix
in what the generator writes beside them:

```dart
part 'counter_bloc.g.dart';

@cobaltTransient
class CounterBloc with _$CounterBloc {
  CounterBloc();

  @injected
  late final Repository _repository;

  @injected
  late final Telemetry _telemetry;

  void increment() => _telemetry.record('${_repository.hashCode}');
}
```

Three things make this safe rather than magic:

- The fields are `late final`, so they are **write-once** — assigning twice throws `LateError`.
- They may be **private**: the generated mixin is a `part` of the same library, so it can see them.
- They are **dependency edges** like any other, so ordering and the completeness check both include
  them.

The `part` directive and the `with _$ClassName` are yours to write. Forget the mixin and
`cobalt_missing_injection_mixin` says so in the editor; put `@injected` on a class the container never
registers and `cobalt_injected_field_needs_an_injectable` says that instead, because the two mistakes
have different fixes.

---

## 5. The graph has to be complete

This is the thing the build step is for. A dependency nothing registers fails the build, naming every
gap at once rather than one per rebuild:

```
The graph is missing 2 registrations.
  CatalogService requires Repository<User>
  ApiGateway requires HttpClient in dev, test
Annotate the classes that provide them with @CobaltInject, or name them in
@CobaltScopeRoot(provides: [...]) when something outside the generated container
registers them.
```

Everything counts as a dependency: constructor parameters, `@injected` fields, and
`@CobaltInit(dependsOn:)`. A `@Named` qualifier is part of the key, so asking for `@Named('audit')
Logger` where only an unnamed `Logger` exists is a gap. Each environment is checked separately, so a
`dev`-only registration cannot satisfy a dependent that also runs in `prod`.

Rejected at build time as well: duplicate registrations of the same key, dependency cycles (naming
the cycle), two `@CobaltScopeRoot` classes in a package, `@CobaltInject` on an abstract class or one
with no public generative constructor, and `@CobaltInject` on a **generic class** — nothing tells the
generator which instantiations to register, so annotate a concrete subtype or expose one with
`exposeAs`.

Generics are fine everywhere else. `Repository<User>` and `Repository<Order>` are two separate
registrations, because `CobaltKey` is built from `Type` and those are different types.

The boundary is worth being honest about: this covers what the generator generated. A hand-written
factory resolves inside `create`, so nothing static can see what it will ask for — for those,
`cobalt_test`'s `expectGraphResolves` is the check, see [§18](#18-tests).

---

**A hand-written registration composed around the container follows the same rule.** A lazy one may
sit above `$CobaltRootScope().build(scope)` and still resolve what the generator registered; an
eager one may not, and the error says so — it names the missing type and adds that the scope is
still being built.

## 6. Composing on top of the generated root

The generator only sees its own package's annotations. Anything else — a value from `--dart-define`,
an object that needs the scope itself, a provider from another package — goes into a builder that
wraps the generated one:

```dart
class NotesScope implements CobaltScopeBuilder {
  const NotesScope(this.environment);

  final CobaltEnvironment environment;

  @override
  void build(CobaltScope scope) {
    $CobaltRootScope(environment: environment).build(scope);
    scope
      ..registerSingleton<CobaltEnvironment>(environment)
      ..registerSingleton<SessionManager>(SessionManager(scope));
  }
}
```

Wrapping rather than registering after `$startCobalt()` returns is what keeps these inside phase 1 —
registered before async initializers run, not bolted on after the graph is already up.

Now tell the completeness check about them, or it will report them as missing:

```dart
@CobaltScopeRoot(name: 'app', provides: [SessionManager, CobaltEnvironment])
class AppScope {
  const AppScope();
}
```

A promise registers nothing; it only says something else will. `CobaltProvided(Logger, name: 'audit')`
promises a named one. Promise something and then fail to register it and you are back to a runtime
failure — the list is a statement you are making, not one the generator can verify.

---

## 7. Starting a Flutter app

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
      root: const NotesScope(notesEnvironment),
      bootstrap: () => $cobaltBootstrap(notesEnvironment),
      rootName: $cobaltRootScopeName,
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: (context, error, retry) => StartupFailed(error: error, retry: retry),
    ),
    home: const HomeScreen(),
  ),
);
```

`bootstrap` is a function rather than a list on purpose, and the generator emits `$cobaltBootstrap` as
a getter for the same reason: steps hold resources, and a restart has to get new ones.

`CobaltAppScope.of(context).restart()` rebuilds the graph — the same call retries a failed start.

Outside Flutter, `await $startCobalt()` is the whole of it.

---

## 8. Reading from the graph in a widget

```dart
final repository = context.cobalt<Repository>();
final formatters = context.cobaltAll<NoteFormatter>();
final editor = context.cobaltWithParam<NoteEditor, $NoteEditorArgs>((id: 7, draft: true));
final scope = context.cobaltScope;
```

Each resolves from the **nearest** scope above the widget and walks up from there, so a registration
in a flow or session scope shadows the root one for everything inside it.

One thing to know before it bites: `Navigator.push` builds the new route from the navigator's
context, not from the widget that pushed it. A screen that resolves fine when mounted in place will
throw `CobaltNoScopeError` when the same widget is pushed, if the provider it was reading lives
*inside* the pushing screen. Pass the scope explicitly in that case, or push below the provider.

---

## 9. Scopes that end before the app does

The generator writes the **root**. Scopes shorter than the app — a session, a flow, a screen — are
`CobaltScopeBuilder`s you write, and they register from the same public API the generated file uses.
That is not a gap in the generator: what belongs in a session scope is a decision about lifetime, and
nothing in an annotation says when a session ends.

### A session

```dart
class SessionManager {
  SessionManager(this._root);

  final CobaltScope _root;
  CobaltScope? _session;

  Future<void> signIn(User user) async {
    _session = _root.push('session:${user.id}')
      ..registerLazySingleton<Draft>(const DraftFactory());
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

### A screen

```dart
CobaltScopeWidget(
  name: 'counter-screen',
  builder: const ScreenScope(),
  child: const Counter(),
)
```

Created when the widget mounts, disposed when it unmounts. The scope is published only after `init()`
completes, so even a fully synchronous graph renders one `loading` frame.

This is where `@cobaltTransient` earns its place: a transient is rebuilt on every resolve and held by
nobody, so giving it a scope of its own is what gives it a lifetime and a disposal point.

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
```

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

## 10. Closing what you registered

A scope releases what it holds, in reverse **creation** order — not declaration order, which is the
bug hand-written containers have. Dart has no structural typing, so a matching `dispose()` method is
not enough on its own:

```dart
@cobaltInject
class Cache implements Disposable {
  @override
  void dispose() { ... }
}

@cobaltInit
class Database implements AsyncInitializable, AsyncDisposable {
  @override
  Future<void> init() async { ... }

  @override
  Future<void> dispose() async { ... }
}
```

For a type you cannot change — from the SDK, from another package, behind a base class — name the
teardown in the annotation. It takes a top-level function, because an annotation argument has to be
a constant:

```dart
Future<void> closeClient(http.Client client) => client.close();

@CobaltInject(dispose: closeClient)
class ApiClientHolder { ... }
```

`dispose:` only means anything on a registration the scope holds. On `@cobaltTransient` or on a class
with `@CobaltParam` it is a build error rather than a callback that never runs, because a transient is
not the scope's to close.

### Flutter types that look closable and are not

`ChangeNotifier.dispose` matches `Disposable.dispose` exactly, and is still invisible to the scope.
Say so:

```dart
@cobaltInject
class Filters extends ChangeNotifier implements Disposable {}
```

For blocs, `cobalt_bloc` is the one line:

```dart
@cobaltInject
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);
}
```

or, where a mixin will not reach, `@CobaltInject(dispose: closeBloc)`.

Then hand it to the widget tree with `BlocProvider.value`, never `BlocProvider(create:)` — the latter
closes what it was given when it unmounts, while the scope still holds it and will hand out the dead
object on the next resolve.

`cobalt_registration_is_never_released` catches all of this in the editor: a registered class with a
`dispose()` or `close()` the scope cannot see.

### When teardown goes wrong

It is best-effort by design. A step that throws is recorded and the rest still run; the whole tree
has one deadline; and the scope always reaches `disposed`. What did not finish is listed in
`CobaltDisposeError` — `failures`, `timeouts`, `hasTimeout` — instead of the first failure hiding the
other nine.

`adopt` ties an object to a scope's life without it being a dependency:

```dart
scope.adopt(subscription, dispose: (it) => it.cancel());
```

---

## 11. Work that has to finish before the app starts

Two phases, answering different questions.

**Phase 0 — `@CobaltBootstrap`.** Before the container exists: platform bindings, remote config,
anything the graph itself needs. Steps run strictly in order — `order` first, then name, so the
output is stable — and can inject nothing, because there is nothing to inject from yet. A bootstrap
step whose constructor takes required parameters is a build error, and
`cobalt_bootstrap_step_cannot_inject` says so before that.

```dart
@CobaltBootstrap(order: 0)
class BindPlatform implements CobaltBootstrapStep {
  const BindPlatform();

  @override
  String get name => 'bind-platform';

  @override
  Future<void> run() async => WidgetsFlutterBinding.ensureInitialized();
}
```

Once they have run, the root scope adopts them, so a step that opened something has it closed at
teardown — last, after everything built on top of it. If a step fails, the ones that already ran are
released in reverse before the error is rethrown.

**Phase 1 — `@CobaltInit`.** Inside the container: async singletons, built in dependency order.

```dart
@CobaltInit(dependsOn: [Database])
class SearchIndex implements AsyncInitializable {
  SearchIndex(this._database);

  final Database _database;
  final _terms = <String>[];

  @override
  Future<void> init() async => _terms.addAll(await _database.terms());
}
```

`AsyncInitializable` is the interface the annotation implies. Only the `init()` *method* is required
— the parser and the lint rule both look for it by name — but declaring the interface is what makes
the contract visible to a reader, and it is what every error message about a missing `init()` tells
you to do.

The generated factory constructs the object, awaits `init()`, and registers it as an async singleton
with `dependsOn` translated into `CobaltKey`s. Independent initializers on the same level run together
through `Future.wait`; only what actually depends waits.

`dependsOn` is an ordering edge, not an injection — you take the dependency in the constructor as
usual. Naming a key that is registered but **not** async is a build error rather than the silent
no-op it looks like: there is no build to wait for.

`CobaltApplication.start` returns when both phases are done, so there is no `allReady()` to call and no
"registered but not ready" state to reason about.

### Built when first asked for

Phase 1 builds everything at startup. For something expensive that lives as long as the app but is
wanted by few screens, mark it lazy, and nothing is built until the first `getAsync`:

```dart
@CobaltInit(lazy: true)   // or @cobaltLazyInit
class SearchEngine implements AsyncInitializable {
  SearchEngine(this._index, this._clock);

  final Model _index;     // itself lazy — the generated factory awaits it
  final Clock _clock;     // an ordinary registration, read as usual

  @override
  Future<void> init() async => _index.warmUp();
}
```

On a module member returning a `Future`, the same is `@CobaltInject(lazyInit: true)`.

The generator registers it with `registerLazyAsyncSingleton`, and its factory awaits
`getAsync` for every dependency that is lazy too. Three things are build errors, because each would
fail on the device instead:

- a synchronous or eager async class that injects a lazy one — there is nothing to hand it until
  someone awaits; make the dependent lazy as well, or resolve it with `getAsync` where it is needed;
- an `@injected` field of a lazy type on any class — fields are filled synchronously;
- `dependsOn` pointing at a lazy registration, or declared on one — `dependsOn` orders `init()`,
  and a lazy registration is not built by `init()`.

At run time it behaves as described in the manual guide: concurrent calls share one build, a failed
build is retried by the next call, `get` before the first `getAsync` throws `CobaltLazyAsyncError`,
and teardown waits for a build in flight. In a widget, `CobaltAsyncBuilder<SearchEngine>` shows
`loading` while the first screen builds it and renders straight away on every screen after.

---

## 12. Values that come from the call site

Half of an object comes from the graph and half from whoever is building it. Mark the half the
container cannot know:

```dart
@cobaltInject
class Greeting {
  Greeting(this._config, {@cobaltParam required this.name, @cobaltParam required this.loud});

  final Config _config;
  final String name;
  final bool loud;
}
```

**A marked parameter always comes from the call site, even when the container could build one.**
`@cobaltParam Draft draft` puts `Draft` in the record whether or not `Draft` is registered, and the
completeness check stops asking for it. That is what marking means, and there is no diagnostic for
marking something the graph already has — so if a value stops arriving, look here before looking at
the registration.

The generator writes the argument type beside the container as a named record and registers a
parameterized factory:

```dart
// typedef $GreetingArgs = ({String name, bool loud});
final greeting = context.cobaltWithParam<Greeting, $GreetingArgs>((name: 'Cobalt', loud: false));
```

A named record rather than positional even for a single argument: adding a second changes the
contents of the type, not its name or the shape of the call.

Two rules the generator enforces:

- Marked parameters are **exempt** from the completeness check and from ordering. Nothing registers a
  `String`, and nothing should try.
- They must be **required or nullable**. A record has no defaults, so `@cobaltParam this.draft = false`
  would leave the caller obliged to pass `draft` while the default it was given is dead. That is a
  build error rather than a surprise.

Resolving one with plain `get<T>()` throws `CobaltParamRequiredError`; passing the wrong type throws
`CobaltParamTypeError` naming the key and both types.

---

## 13. Optional dependencies

A `?` on the type is the whole spelling — there is no annotation, because without the `?` the field
could not hold null anyway:

```dart
@cobaltInject
class Reporter {
  Reporter(this.clock, this.telemetry);

  final Clock clock;
  final Telemetry? telemetry;
}

@cobaltInject
class Dashboard with _$Dashboard {
  Dashboard();

  @injected
  late final Telemetry? _telemetry;
}
```

Both resolve through `getOrNull`, so a graph that registers no `Telemetry` injects null instead of
failing the build.

Nullability is not part of the registration **key** — `Foo?` still reads the `Foo` registration — and
an optional dependency is still an ordering edge when something does register it. `getOrNull` returns
null only for "nothing is registered": an async singleton asked for before `init()` still throws,
because "not ready" and "not there" are different facts.

---

## 14. Types you did not write

`@CobaltInject` goes on a class, so it only reaches classes you own. A module is the way in for
everything else — a client from another package, a value the SDK hands you:

```dart
Future<void> closeClient(http.Client client) => client.close();

@cobaltModule
class NetworkModule {
  const NetworkModule();

  @cobaltInject
  Dio dio(AppConfig config) => Dio(BaseOptions(baseUrl: config.apiBase));

  @CobaltInject(dispose: closeClient)
  http.Client client() => http.Client();

  @cobaltSingleton
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
```

The annotation on the class carries nothing: every member configures its own registration with the
same annotations a class uses — lifetime, `name`, `exposeAs`, `dispose`, environments — and its
parameters are resolved like constructor parameters.

The rules, each with a reason:

- The class needs a public **`const` constructor taking no arguments**, so the emitted factory holds
  `const NetworkModule()` and carries no state.
- Returning **`Future<T>` is the only async signal.** Such a member becomes an async singleton, and
  the order between async members is worked out by the generator rather than written by hand.
- Members **cannot be abstract.** Building a class from its own constructor is what `@CobaltInject`
  already means; there is no second way to say it.
- `@CobaltParam` is **not** allowed on a member. A module registers types you did not write; a value
  from the call site belongs to a class you did.

Members participate in everything a class does: duplicate detection, topological ordering, and the
completeness check.

### Wrapping a registration

`@CobaltDecorates` wraps what a registration hands out without touching its class — logging,
retries, a cache, a metric around a client from another package:

```dart
@CobaltDecorates(ApiClient)
class LoggingApi implements ApiClient {
  LoggingApi(this._inner, this._log);

  final ApiClient _inner;
  final Logger _log;
}
```

The class is not registered. The generator emits a `CobaltDecorator` around it and a
`scope.decorate<ApiClient>(...)` in `build()`, so every `get<ApiClient>()` — injected fields
included — receives the wrapper. `examples/codegen_basics` has one on `Repository`.

The rules, each with a reason:

- The class **implements the target** and takes **exactly one** constructor parameter of that type:
  the instance it wraps. Every other parameter is resolved from the scope that owns the
  registration, `@Named` included. `@CobaltParam` and `@injected` fields are refused — the scope
  applies a decorator, and there is no call site.
- Two decorators of one registration need an **`order:`**; the lower one is innermost. The build
  refuses to guess, and refuses two equal orders. Decorators whose environments never meet do not
  compete.
- The target has to be **registered wherever the decorator is active**, or named in `provides:`.
  Its dependencies go through the completeness check like any class's, and a decorator needing
  something that depends on its own target is a cycle.
- A decorator **cannot take a lazy async registration**: it runs synchronously, when the instance
  is handed out. Wrapping a lazy one is fine.
- An async class that resolves a decorated registration while phase 1 runs **waits for what the
  decorator resolves**. The generator adds that to its `dependsOn` — on the consumer, not the
  target, so an override of the target keeps the wait.

At runtime it is the same `decorate` as in Manual Mode: a retained registration is decorated once
and shared, an override is decorated like the registration it replaced, and the scope closes the
inner instance, never the decorator.

---

## 15. One graph, several builds

Skip this until one build genuinely needs a different implementation than another. A project that
never writes `@CobaltEnvironment` has one graph, every registration belongs to it, and `$startCobalt()`
takes no argument at all.

```dart
@CobaltInject(exposeAs: ApiClient)
@CobaltEnvironment.prod
@CobaltEnvironment.stage
class LiveApiClient implements ApiClient { ... }

@CobaltInject(exposeAs: ApiClient)
@CobaltEnvironment.dev
@CobaltEnvironment.test
class FakeApiClient implements ApiClient { ... }
```

```dart
final scope = await $startCobalt(environment: CobaltEnvironment.prod);
```

The annotation repeats rather than taking a list: a registration belongs to a *set* of environments
while startup picks exactly *one*. `dev`, `stage`, `prod` and `test` are constants, not a closed set
— `@CobaltEnvironment('canary')` behaves identically.

The generated container takes the choice as a field and guards only the restricted registrations,
which is exactly what you would write by hand:

```dart
if (environment.matches(const <String>{'dev', 'test'})) {
  scope.registerLazySingleton<ApiClient>(const _FakeApiClientFactory());
}
```

Three things follow:

- **It stays opt-in to the end.** The parameter appears only once something names an environment, and
  even then defaults to `CobaltEnvironment.defaultEnvironment` — the single environment an unsplit
  graph lives in. That default matches unrestricted registrations and nothing else, so starting a
  split graph without choosing leaves the split types unregistered and the first resolve fails saying
  so, rather than quietly handing back the wrong class.
- **Nothing is registered twice.** Two registrations of the same key whose environments overlap are a
  build failure naming both — including the case where one names no environment at all, since an
  unrestricted registration is present everywhere.
- **Completeness is checked per environment**, so a `dev`-only registration cannot satisfy a
  dependent that also runs in `prod`.

Bootstrap steps take environments too. When any of them does, `$cobaltBootstrap` becomes a function of
the chosen environment, and skipped steps never run and never get adopted.

`cobalt_environment_needs_a_registration` catches the case where `@CobaltEnvironment` sits on a class
nothing registers, where it silently does nothing.

---

## 16. The lint plugin

Fourteen rules, built on the same parsing layer the generator uses, so a mistake surfaces in the editor
rather than only when `build_runner` runs.

```yaml
# analysis_options.yaml
plugins:
  cobalt_lint: ^0.2.0
```

| Rule | Catches |
|---|---|
| `cobalt_missing_injection_mixin` | `@injected` fields without `with _$ClassName`, on a class the container registers |
| `cobalt_injected_field_needs_an_injectable` | `@injected` fields on a class the container never registers |
| `cobalt_param_needs_an_injectable` | `@CobaltParam` on a class the container never registers |
| `cobalt_injected_field_must_be_late_final` | `@injected` on a mutable, non-late, or static field |
| `cobalt_injectable_must_be_constructible` | `@CobaltInject` on an abstract class or one with no public generative constructor |
| `cobalt_init_requires_init_method` | `@CobaltInit` on a class with no `init()` |
| `cobalt_bootstrap_requires_run_method` | `@CobaltBootstrap` on a class with no `run()` |
| `cobalt_bootstrap_step_cannot_inject` | a bootstrap step whose constructor takes required parameters |
| `cobalt_environment_needs_a_registration` | `@CobaltEnvironment` on a class nothing registers |
| `cobalt_dependency_is_not_registered` | an injected dependency nothing in the package registers |
| `cobalt_dependency_cycle` | an injectable class that depends, eventually, on itself |
| `cobalt_registration_is_never_released` | a registered class with a `dispose()` or `close()` the scope cannot see |
| `cobalt_resource_is_never_closed` | A registration holds something closeable and offers no way to close it |
| `cobalt_lazy_registration_injected_synchronously` | a lazy async registration injected where nothing can wait for it — a synchronous or eager constructor, or an `@injected` field |

Two things about wiring it up cost real time:

1. The `plugins:` section **only works at the root of a package or workspace**. In a nested
   `analysis_options.yaml` it is silently ignored — no error, no diagnostics. For the same reason
   `dart analyze <nested/dir>` does not apply it; analyze the workspace root.
2. The analysis server caches its build of the plugin per context. "The rule does not fire" usually
   means a stale build, not a wrong rule — touch the plugin's file, or restart the server.

The last two rules answer questions the generator answers too, only earlier and without a full build.
They are deliberately quieter than the generator: they read a syntactic index of the package, so
where the index cannot be sure, they say nothing rather than reporting something that is fine. The
build is the authority; the editor is the fast path.

---

## 17. Watching the graph

Observers see scopes appearing, instances being built, startup finishing, teardown failing. Pass them
where the graph is created; every scope pushed below inherits them.

`$startCobalt()` does not take observers — it is the short path. Once you want them, go through the
builder you are already composing:

```dart
final scope = await CobaltApplication.start(
  root: const NotesScope(notesEnvironment),
  bootstrap: $cobaltBootstrap(notesEnvironment),
  rootName: $cobaltRootScopeName,
  observers: [CobaltLogObserver(const CobaltDeveloperLogSink())],
);
```

In a Flutter app it is the `observers:` parameter of `CobaltAppScope.builder`.

Callbacks get `CobaltScopeRef` and `CobaltKey` — descriptions, not live objects — and an exception
thrown from one is swallowed: watching must not be able to break what it watches. Resolution is not
reported; a cache hit is the hot path, and what is worth seeing is an instance being *built*.

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

## 18. Tests

The first thing to know is a trap, not an API. `testWidgets` runs its body inside a fake-async zone,
where a `Future.delayed` in an initializer never completes. **Build the graph in `setUp`**, and keep
whole-graph assertions in a plain `test`.

```dart
late CobaltScope scope;

setUp(() async {
  scope = await cobaltTestScope(root: const $CobaltRootScope());
});
```

The generated builder goes straight in, exactly as the app uses it. `cobaltTestScope` and
`cobaltTestRoot` dispose with the test, which is the part that is easy to leave out — and leaving it
out leaks into the next test rather than failing.

### Overriding

Hand the replacement to the generated start function, or to the test helper that calls it. It lands
in the root, where everything generated is registered, and the generated registration of the same
key is skipped rather than rejected as a duplicate:

```dart
final scope = await cobaltTestScope(
  root: const $CobaltRootScope(),
  overrides: [CobaltOverride<ApiClient>.value(FakeApiClient())],
);
```

`$startCobalt(overrides: [...])` takes the same list, and `CobaltAppScope(overrides: () => [...])`
a function called on every start, so a restart does not get back a value the previous graph already
closed — a flavour or a debug menu is the case in an app. `.value` takes a built object, `.lazy` and
`.transient` a factory, and `CobaltParamOverride<T, P>` a parameterized one. An eager singleton is
emitted as `registerEagerSingleton`, so an overridden one is never built at all.

An override is never silent: observers receive `onRegistrationOverridden`, and `overriddenKeys`
lists what is replaced. Name the type argument — inside the list Dart infers it as `Object`, which
the scope refuses as soon as it is created.

Shadowing from a child scope still works, and reaches only what is resolved from the child:

```dart
final overrides = scope.pushForTest()
  ..registerSingleton<ApiClient>(FakeApiClient());
```

**A factory runs on the scope that owns its own registration**, and everything generated lives in
the root, so every generated consumer keeps the real `ApiClient`. `ownerOf<T>()` says so before the
test does:

```dart
expect(scope.ownerOf<Repository>(), same(scope.root));
```

### What still needs checking at run time

The completeness check covers the generated container. Two things sit outside it and are worth a
test:

```dart
await expectGraphResolves(scope);
```

The first is anything you promised with `provides:` — the check trusted you. The second is any
hand-written registration you composed in ([§6](#6-composing-on-top-of-the-generated-root)).

It is terminal: resolving *is* the check, so afterwards every lazy singleton is built and the
teardown order is different. Put it in a test of its own. A parameterized registration is reported by
name as `unchecked` rather than skipped in silence — hand it a sample to cover it:

```dart
await expectGraphResolves(scope, params: {CobaltKey(Greeting): (name: 'x', loud: false)});
```

### Fixtures

```dart
final scope = cobaltTestRoot()
  ..registerLazySingleton<Clock>(FnFactory((_) => FixedClock(DateTime(2026))))
  ..registerSingleton<Config>(const Config())
  ..registerAsyncSingleton<Db>(AsyncFnFactory((_) async => Db()));

await scope.init();
```

These save writing a factory class per stub in tests that do not want the whole generated graph.
Async registrations have to exist **before** `init()`, which is why fixtures go into a fresh root
rather than into a scope that has already started.

`DisposeRecorder` is the fixture for teardown assertions, with a log per instance rather than a
shared one, so a scope disposed after the test that made it cannot report into the next.
`CapturingObserver` collects events for assertions about what the graph did.

### Widget tests

`cobalt_test_flutter` carries the two helpers whose obvious spelling is wrong:

```dart
await settle(tester);                    // not pumpAndSettle: it spins forever on a loading indicator
final scope = mountedRootScope(tester);  // the app's graph, from below the MaterialApp builder
```

### Keeping generated code honest in CI

Regenerate and fail on a diff:

```bash
dart run build_runner build
git diff --exit-code
```

Without it, generated output drifts from the annotations and nobody notices until the graph is wrong
at run time.

---

## 19. Mistakes worth knowing about in advance

Each of these was found the hard way, in this repository or in the applications it was written for.

- **Not committing `cobalt.g.dart`, or committing a stale one.** Regenerate in CI and diff. This is
  the mode's one real maintenance obligation.
- **Two `@CobaltScopeRoot` classes in one package.** A build error, and the fix is two packages —
  `cobalt_container` aggregates a whole package into one root.
- **`@CobaltInject` on a generic class.** Rejected: nothing tells the generator which instantiations
  to register. Annotate a concrete subtype, or expose one with `exposeAs`. Generics work fine as
  dependencies and as `exposeAs` targets.
- **`@injected` without `with _$ClassName`.** The fields stay unassigned and the first read throws
  `LateError`. The lint says so first.
- **Promising with `provides:` and then not registering it.** The check believed you, so the failure
  moves to run time. Cover it with `expectGraphResolves`.
- **Building the graph inside `testWidgets`.** Fake-async, no completion, a timeout with nothing to
  point at. `setUp`.
- **Overriding below the consumer.** The factory runs on the owning scope. `ownerOf<T>()` tells you
  before the assertion does.
- **`BlocProvider(create:)` for a bloc the scope owns.** Two owners, and the widget wins first.
  `BlocProvider.value`.
- **A `ChangeNotifier` or `Cubit` registered without saying it is closable.** Built, used, never
  closed, silently. `implements Disposable`, `with CobaltBloc`, or `dispose:`.
- **An old `dart` first on PATH.** It fails quietly and in the wrong place — `dart analyze` reports
  phantom issues against the wrong analyzer, and generated output shifts between formatter versions.
  Check `dart --version` before believing a run.

---

## Where to go next

- [GUIDE_MANUAL.md](GUIDE_MANUAL.md) — the same runtime without the build step, and what composes
  with what.
- [README.md](README.md) — what Cobalt is, and why each decision went the way it did.
- [MIGRATION.md](MIGRATION.md) — from `get_it` and `injectable`, including what does not translate.
- `examples/codegen_basics` is the smallest generated setup, and `examples/notes_app` the largest.
  Both run from the gallery: `cd examples/gallery && flutter run`.
