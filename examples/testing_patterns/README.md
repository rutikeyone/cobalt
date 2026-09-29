# testing_patterns

How to test an app built on Cobalt. The interesting code is in `test/`.

```bash
flutter test
```

## Overriding a dependency

Push a child scope and register it again. Registering twice in *one* scope is
an error — that catches a real mistake. Shadowing from a child is the supported
way, and it is the same mechanism production code uses for session and flow
scopes: tests get no special path, and no `@visibleForTesting` back door exists
to keep in sync.

## The sharp edge, and the reason this example exists

A factory is called with the scope that **owns the registration**, not the
scope you asked from. So:

```dart
final scope = app.push('test')
  ..registerSingleton<GreetingStore>(const InMemoryGreetingStore('Hello'));

scope.get<Greeter>();   // still uses the REAL store
```

`Greeter` lives in the root, so it resolves `GreetingStore` from the root. The
child's fake is invisible to it. This is not a bug — a root singleton whose
dependencies varied by caller would not be a singleton — but it surprises
everyone once.

The fix is to override the consumer too:

```dart
final scope = app.push('test')
  ..registerSingleton<GreetingStore>(const InMemoryGreetingStore('Hello'))
  ..registerLazySingleton<Greeter>(const GreeterFactory());
```

Rule of thumb: **override at or above the level you resolve from.**

## Keeping the graph's shape

`test/graph_snapshot_test.dart` compares the production graph with
`test/app_graph.snapshot`. A registration added or a lifetime changed fails it
with a diff, so the change is looked at in review. Accept one with:

```bash
COBALT_UPDATE_SNAPSHOTS=1 flutter test test/graph_snapshot_test.dart
```

## Two more things worth knowing

**Build the graph in `setUp`, not inside `testWidgets`.** `testWidgets` runs
its body in a fake-async zone where a real `Future.delayed` never completes, so
an async initializer started in there hangs until the suite times out — with
nothing pointing at the cause. Assertions about the graph alone belong in a
plain `test`.

**Fakes live in `lib/`, not `test/`.** Anything depending on this package can
then reuse them, the same reason a package ships a `*_test_utils` library.

## Why this matters

The apps that motivated Cobalt had no tests at all, and their own tech-debt
notes said only the code written *without* DI was testable. A container you
cannot substitute into is a container that makes testing worse. This example
exists to show that the substitution point is ordinary API, not a special mode.
