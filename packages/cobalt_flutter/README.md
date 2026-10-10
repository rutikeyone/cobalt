<p align="center">
  <img src="https://raw.githubusercontent.com/rutikeyone/cobalt/main/assets/banner.png" alt="Cobalt, dependency injection for Dart and Flutter" width="880">
</p>

<p align="center">
  <a href="https://pub.dev/packages/cobalt_flutter"><img src="https://img.shields.io/pub/v/cobalt_flutter?logo=dart&logoColor=white&label=pub&color=5FD4C8" alt="pub package"></a>
  <a href="https://pub.dev/packages/cobalt_flutter/score"><img src="https://img.shields.io/pub/points/cobalt_flutter?color=5FD4C8" alt="pub points"></a>
  <a href="https://github.com/rutikeyone/cobalt/actions/workflows/ci.yml"><img src="https://github.com/rutikeyone/cobalt/actions/workflows/ci.yml/badge.svg" alt="ci"></a>
  <a href="https://github.com/rutikeyone/cobalt/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="licence"></a>
</p>

# cobalt_flutter

Dependency injection for Flutter apps, where the app, a session or a screen owns a scope, and
everything built in it is closed when that scope ends.

## Why Cobalt

- **Objects go away with the screen, flow or session that needed them.** No `reset()` methods and
  no listeners waiting for a logout event.
- **A missing dependency fails the build, not the app.** `build_runner` names every gap at once.
- **Startup has a loading screen and an error screen.** Services that must be awaited start before
  the first screen, and a failed start is a screen with a retry instead of a crash.
- **Tests swap a dependency for everyone.** There is no global container, so tests run in parallel.
- **The generated code is plain Dart** that you can read, or write by hand instead.

<p align="center">
  <img src="https://raw.githubusercontent.com/rutikeyone/cobalt/main/assets/quick-tour.gif" width="300" alt="A tour of the gallery: a session scope opened, then the live scope tree">
</p>

<p align="center"><sub>The gallery: open a session scope, then look at the live scope tree in <code>cobalt_inspector</code>.</sub></p>

## Install

```bash
flutter pub add cobalt cobalt_flutter dev:cobalt_generator dev:build_runner
```

`cobalt` is the runtime: the generated `lib/cobalt.g.dart` imports it, so the app depends on it
directly.

## Quick start

Replace `lib/main.dart` of a new app (`flutter create my_app`):

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

1. **Annotate.** `@cobaltInject` registers `Clock` and `Greeter`. `Greeter` asks for a `Clock` in
   its constructor, and that is all the wiring you write.
2. **Generate.** `dart run build_runner build` writes `lib/cobalt.g.dart`, whose `CobaltRoot`
   connects the two. Delete `test/widget_test.dart`, which tests the counter app that is gone, then
   `flutter run`. Anything else in red is in
   [the first build](https://github.com/rutikeyone/cobalt/blob/main/docs/TROUBLESHOOTING.md#the-first-build).
3. **Read.** `CobaltAppScope` builds the graph when the app starts and closes it when the app goes,
   and `context.cobalt<Greeter>()` reads from it in any widget below.

The same app, with a test that swaps the clock, is
[`examples/hello`](https://github.com/rutikeyone/cobalt/tree/main/examples/hello).

## Key features

- **Scopes owned by widgets.** `CobaltScopedWidget` creates a scope when a screen mounts and closes
  it when the screen goes.
  [Read more](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_CODEGEN.md#9-scopes-that-end-before-the-app-does)
- **Async startup with loading and error screens.** `CobaltAppScope` awaits what must be ready
  before the first frame and shows `loading`, or `errorBuilder` with a retry.
  [Read more](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_CODEGEN.md#7-starting-a-flutter-app)
- **Tests swap a dependency.** `overrides` replaces a registration for every consumer, in a widget
  test or a debug build.
  [Read more](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_CODEGEN.md#18-tests)
- **An inspector inside the app.** The live scope tree and every event the graph reported, on a
  screen of your debug menu. [Read more](https://pub.dev/packages/cobalt_inspector)

## Learn more

| | |
|---|---|
| **Step by step, with the generator** | [GUIDE_CODEGEN.md](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_CODEGEN.md) |
| **Step by step, without code generation** | [GUIDE_MANUAL.md](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_MANUAL.md) |
| **Something threw** | [docs/TROUBLESHOOTING.md](https://github.com/rutikeyone/cobalt/blob/main/docs/TROUBLESHOOTING.md) |
| **Coming from get_it, injectable or provider** | [MIGRATION.md](https://github.com/rutikeyone/cobalt/blob/main/MIGRATION.md) |
| **The smallest app** | [`examples/hello`](https://github.com/rutikeyone/cobalt/tree/main/examples/hello) |
| **Every feature in one app** | [`examples/gallery`](https://github.com/rutikeyone/cobalt/tree/main/examples/gallery) |

## Reference

Everything below describes the package in full.

`CobaltScopeProvider` publishes a scope you built yourself:

```dart
CobaltScopeProvider(
  scope: await $startCobalt(),
  child: const MyApp(),
);
```

Resolve from any descendant:

```dart
final repo = context.cobalt<NoteStore>();
```


## Widget-owned scopes

A scope can belong to a piece of UI: created when it mounts, disposed when it unmounts, so a
screen's dependencies live exactly as long as the screen.

The short way is to extend `CobaltScopedWidget`, which collapses the scope declaration, the wrapper
and the content into one class:

```dart
class NoteDetailScreen extends CobaltScopedWidget {
  const NoteDetailScreen({super.key});

  @override
  void registerScope(CobaltScope scope) =>
      scope.registerLazySingleton<NoteDraft>(const NoteDraftFactory());

  @override
  Widget buildScoped(BuildContext context) =>
      Text(context.cobalt<NoteDraft>().text);
}
```

`buildScoped` runs below the scope, so `context.cobalt<T>()` resolves from it. Override `scopeName`,
`loading`, `errorBuilder` or `overrides` when the defaults do not fit; the scope is otherwise named after the
widget, which is what shows up in the scope tree.

`CobaltScopedStatefulWidget` is the stateful counterpart — the widget declares the scope, its
`CobaltScopedState` overrides `buildScoped`, and `setState` rebuilds only the content. The scope is
created once on mount, not on every rebuild.

Use `CobaltScopeWidget` directly when the scope has to wrap part of a subtree rather than a whole
widget:

```dart
CobaltScopeWidget(
  builder: const NoteDetailScope(),
  loading: const CircularProgressIndicator(),
  errorBuilder: (context, error) => ErrorView(error),
  child: const NoteDetailPage(),
)
```

`name` is optional everywhere and defaults to the builder's type. If the scope registers async
singletons, `loading` is shown while `init()` runs and `errorBuilder` receives anything it throws —
and so does a builder that throws, in which case the half-built scope is disposed rather than left in
the tree.

`overrides` replaces what this scope registers, the same way it does on the root — in a widget test
mounting one screen, or a debug build of it:

```dart
CobaltScopeWidget(
  builder: const NoteDetailScope(),
  overrides: () => [CobaltOverride<NoteDraft>.value(NoteDraft('fixture'))],
  child: const NoteDetailPage(),
)
```

It is a function called on every mount, because the scope closes a value handed over with
`CobaltOverride.value` when it unmounts. It reaches only this scope's registrations: overriding a key
an ancestor owns replaces nothing, since the ancestor's factories never see this scope, and it fails
naming that ancestor — override it there instead.

## A lazy async registration on one screen

Something expensive that lives as long as its scope but is wanted by one screen is registered with
`registerLazyAsyncSingleton` (or `@CobaltInit(lazy: true)`), and `CobaltAsyncBuilder` is how the
screen waits for it:

```dart
CobaltAsyncBuilder<SearchEngine>(
  loading: const Center(child: CircularProgressIndicator()),
  errorBuilder: (context, error, retry) => RetryView(onRetry: retry),
  builder: (context, engine) => SearchScreen(engine: engine),
)
```

The first screen to mount it builds the engine and shows `loading` meanwhile; every later one finds
it built and renders without a frame of `loading`. The resolution is held in the widget's state, so
a parent rebuild neither restarts it nor retries a failed one by itself — `retry` does. Without an
`errorBuilder` the failure is rethrown during build. For a one-off await outside a builder,
`context.cobaltAsync<T>()` reads through the nearest scope.

To have it ready before the screen opens, list it in `CobaltAppScope(warmUp: [...])`: the build
starts as soon as the graph is up, behind `child` rather than behind `loading`, and a screen that
opens early waits for that same build. A failed warm-up goes to `FlutterError.reportError` — the app
is already running — and the next `getAsync` tries again. `CobaltScope.warmUp` does the same from
anywhere else, a login handler for instance.

## Who owns the root scope

`CobaltAppScope` does. It takes the graph the same way `CobaltApplication.start` does, builds it,
publishes it, and disposes it on unmount. Its usual home is `MaterialApp.builder`:

```dart
void main() => runApp(
  MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    builder: CobaltAppScope.builder(
      root: const AppScope(),
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: (context, error, retry) => StartupFailed(error, retry),
    ),
    home: const HomeScreen(),
  ),
);
```

`initTimeout: const Duration(seconds: 15)` turns a start that hangs into that `errorBuilder` screen,
with a `CobaltInitTimeoutError` naming the async singletons that never finished — instead of a
`loading` screen that stays up forever.

A hot reload that adds, removes or re-lifetimes a registration in `root` restarts the graph and says
what changed in the debug console; any other reload keeps it, and the screens below, as they were.
`restartOnGraphChange: false` opts out.

In Code-Gen Mode the three generated names go straight in — no wrapper function in between:

```dart
builder: CobaltAppScope.builder(
  root: $CobaltRootScope(environment: environment),
  bootstrap: () => $cobaltBootstrap(environment),
  rootName: $cobaltRootScopeName,
),
```

**Why `builder` and not above the app.** Everything `MaterialApp.builder` returns sits below
`Theme`, `Directionality`, `MediaQuery` and `Localizations`, and the child it hands you is the
navigator. So `loading` and `errorBuilder` are ordinary screens with the app's theme — put the
scope *above* `MaterialApp` instead and they have no theme at all, which is why they would each
need a throwaway `MaterialApp` of their own.

If the app already uses `builder`, compose the two yourself; merging two builders is the app's
decision, not the framework's:

```dart
builder: (context, child) => CobaltAppScope(
  root: const AppScope(),
  child: MyOwnWrapper(child: child!),
),
```

**`bootstrap` is a function, not a list.** Bootstrap steps are instances that hold resources, so a
stored list would hand a restart the same objects it just released — the defect that made the
generated `$cobaltBootstrap` a getter in the first place. `root` *is* a plain value, because an
`CobaltScopeBuilder` only registers and carries no state.

For a graph the declarative form cannot express, `CobaltAppScope.start(start: () async { ... })`
takes a function returning a started scope.

Building the graph *inside* `runApp` rather than before it is the point. `runApp(App(scope: await
start()))` has no way to show a startup failure — the app dies before its first frame. Here the
failure is a screen with a retry. As a bonus, `WidgetsFlutterBinding` is already initialized when
`@CobaltBootstrap` steps run.

`CobaltAppScope.of(context).restart()` tears the graph down and builds a new one; it is the same
call that retries a failed start. The published provider is keyed by the scope, so a restart
rebuilds the subtree — a child scope cannot be reparented, and would otherwise be left pointing at
a root that is gone.

### Replacing part of the graph

`overrides` swap a registration where it is owned — a flavour, a debug menu, a widget test. Like
`bootstrap`, it is a function called on every start and restart:

```dart
builder: CobaltAppScope.builder(
  root: const AppScope(),
  overrides: () => [CobaltOverride<ApiClient>.value(FakeApiClient())],
),
```

A function rather than a list for the same reason: the scope owns a value handed over with
`CobaltOverride.value` and closes it with the graph, so a stored list would give a restart the very
object the previous graph just closed.

Observers are told each time a registration is skipped for one, so a build running with a
replacement never does so silently.

### Changing the graph needs a key, or `restart()`

`CobaltAppScope` reads `root` and `bootstrap` once, when it mounts. It has no
`didUpdateWidget`, so putting a *different* graph in the same slot leaves the
widget owning the graph it already built — and the next `context.cobalt<T>()`
looks in the wrong one, failing with "not registered" for something that is
plainly registered in the graph you thought you passed.

Two ways out, depending on what you meant. To replace one graph with another,
give the widget a `key` that changes with the graph, so Flutter builds a new
element instead of updating the old one. To rebuild the *same* graph, call
`CobaltAppScope.of(context).restart()`, which disposes the old root first.

This mostly does not come up, because a route push builds a new element
anyway. It bites in tests that pump one graph after another into the same
position.

### Hot reload keeps the graph; hot restart rebuilds it

Measured on the iOS simulator, because the behaviour is easy to assume and
easy to get wrong.

**Hot reload leaves the graph alone.** `CobaltAppScope` keeps its state, so the
root scope is not rebuilt: no bootstrap step re-runs, no initializer re-runs,
and every instance stays the one it was. Editing a widget takes effect
immediately, which is the point.

**That includes edits to registered classes**, and this is the part that
surprises people. Change what a factory or a bootstrap step produces, hot
reload, and the screen still shows the *old* value — the instance already
exists and nothing asked for a new one. Cobalt is doing what a singleton is for.
When you are iterating on a service's construction, use hot restart, or call
`CobaltAppScope.of(context).restart()` to rebuild only the graph while the app
keeps running.

**Hot restart rebuilds everything**: a new isolate, so statics reset, phase 0
runs again, and the new code takes effect.

One caveat about hot restart, inherent to Flutter rather than to Cobalt: it
replaces the isolate outright, so `dispose()` never runs. Whatever the old
graph held — a socket, a file handle, a native binding — is dropped rather than
released. `restart()` does not have this problem; it disposes the old root
before building the new one.

### `disposeOnExitRequest` is off by default

Turning it on disposes the graph when the OS asks the app to quit. It is off because the hook
behind it only fires where an exit is cancelable — Flutter's own docs say "Currently this is only
supported on macOS and Linux" — and is blunt about the rest:

> Do not rely on this function as a place to save critical data, because you will be disappointed.

On iOS and Android the process can be killed with no notification at all. So this is a desktop
nicety, not a guarantee, and it delays quitting by however long teardown takes.

One sharp edge if you do enable it: Flutter asks *every* observer before quitting and does not stop
at the first refusal. If another observer cancels the exit after this one has already disposed, the
app keeps running with no graph and shows `loading` until something calls `restart()`.

## Objects that cannot say how to close themselves

A scope releases what it built, in reverse creation order. It recognises exactly two things —
`Disposable` and `AsyncDisposable` — plus whatever a registration named a `dispose:` function for.
Dart has no structural typing, so **a matching method signature is not enough**, and almost every
object a Flutter app registers has one without the declaration:

| Type | What it has | What it needs |
|---|---|---|
| `ChangeNotifier`, `ValueNotifier` | `void dispose()` | `implements Disposable` — nothing else, the signature already matches |
| `Bloc`, `Cubit` | `Future<void> close()` | `with CobaltBloc` from [`cobalt_bloc`](https://pub.dev/packages/cobalt_bloc), or the same two lines by hand |
| `StreamController` | `Future close()` | `dispose:` at the registration — it is not yours to change |

```dart
class NotesController extends ChangeNotifier implements Disposable {}

class SessionCubit extends Cubit<Session> implements AsyncDisposable {
  @override
  Future<void> dispose() => close();
}

scope.registerSingleton(StreamController<Event>(), dispose: (it) => it.close());
```

In Code-Gen Mode the third route is `@CobaltInject(dispose: closeIt)`, pointing at a top-level or
static function that takes the registered type.

Forgetting the declaration is quiet: the object is built, used, and never closed. This is the single
most common way to leak with Cobalt, and `packages/cobalt_flutter/test/flutter_teardown_test.dart`
pins all four cases so the behaviour cannot drift into something the documentation does not say.

## The two errors you will actually meet

`CobaltNoScopeError` — nothing publishes a scope above the widget that asked. Usually a missing
provider, but the other cause looks nothing like one and has cost this repository four separate
debugging sessions: **a route pushed with `Navigator.push` is built by the navigator, which sits
above any provider mounted inside a screen.** Code that resolved fine in place throws the moment the
same widget is opened as a pushed route. Read the scope where the push happens and pass it into the
pushed widget, rather than reading it there.

`CobaltNoAppScopeError` — nothing *owns* a root scope above the widget that asked to restart it.
`CobaltScopeProvider` publishes a scope somebody else owns; only `CobaltAppScope` owns one, and only
an owner can take it down and build it again.

Both are `CobaltError` subclasses, so a test can name the one it expects instead of matching on
message text.
