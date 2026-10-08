# cobalt_test

Test helpers for [Cobalt](https://pub.dev/packages/cobalt): build and tear down graphs, override
dependencies, and check that a hand-written graph resolves.

Pure Dart, on `test_api` and `matcher` rather than the full `test` runner, so the same helpers work
under `dart test` and `flutter test`.

```bash
dart pub add dev:cobalt_test
```

A test of the `Greeter` from the
[`cobalt_flutter` Quick start](https://pub.dev/packages/cobalt_flutter#quick-start), with the clock
fixed so the greeting no longer depends on the time of day:

```dart
class FixedClock implements Clock {
  FixedClock(this.time);

  final DateTime time;

  @override
  DateTime now() => time;
}

test('greets in the morning', () async {
  final app = await cobaltTestScope(
    root: const $CobaltRootScope(),
    overrides: [
      CobaltOverride<Clock>.value(FixedClock(DateTime(2026, 10, 7, 9))),
    ],
  );

  expect(app.get<Greeter>().greet('Cobalt'), 'Good morning, Cobalt!');
});
```

`cobaltTestScope` starts the same graph the app starts, with `Clock` replaced for everything that
asks for it, and disposes it when the test ends.

Learn more: tests in the [Code-Gen guide](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_CODEGEN.md#18-tests)
and the [Manual guide](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_MANUAL.md#13-tests), and
[`cobalt_test_flutter`](https://pub.dev/packages/cobalt_test_flutter) for widget tests.

## Building a graph

```dart
late CobaltScope app;

setUp(() async {
  app = await cobaltTestScope(root: const AppScope(), rootName: 'app');
});
```

Teardown is registered for you. `cobaltTestRoot()` is the bare equivalent for unit tests that
register a few things directly and never need two-phase startup.

## Overriding

Hand the replacement to the scope that owns the key, and every consumer registered there sees it:

```dart
final scope = await cobaltTestScope(
  root: const AppScope(),
  overrides: [CobaltOverride<Clock>.value(FixedClock(DateTime.utc(2026)))],
);
```

`cobaltTestRoot` and `pushForTest` take `overrides` too. It is the same mechanism an app uses for a
flavour, not a back door for tests.

Shadowing from a child still works, for what is resolved from the child:

```dart
final scope = app.pushForTest()
  ..registerSingleton<Clock>(FixedClock(DateTime.utc(2026)));
```

`ownerOf<T>()` answers the question that trips everyone once: a factory runs on the scope that owns
**its** registration, not the scope you asked from, so a shadow below the consumer is invisible to
it — that consumer wants an override where it is owned.

```dart
expect(scope.ownerOf<Greeter>(), same(scope)); // fails if Greeter is owned above
```

## Checking a hand-written graph

The generator rejects an incomplete graph at build time, but it only sees what it generated. A
factory never declares what it will ask for, so a graph assembled by hand can only be checked by
running it:

```dart
await expectGraphResolves(app);
```

`checkGraph` returns the detail instead of throwing. Both report every hole at once — a graph with
three of them should take one run to find, not three.

**This is terminal for the scope.** Resolving *is* the check, so there is no dry run, and afterwards
every lazy singleton is built and owned — which changes the order teardown releases things in. Give
it a scope nothing else asserts on, or make it the last thing the test does.

Two things it cannot resolve, and says so rather than passing over them:

| Kind | What happens |
|---|---|
| parameterized | listed as unchecked **by name**, unless you pass a value in `params` |
| eager singleton | reported as resolved, but its factory ran at registration — nothing was proven |

Transients are built and disposed here, since the scope does not retain them. Async singletons have
their owning scope initialised first.

## Keeping the graph's shape

`describeGraph(scope)` renders what each scope registers — kind, overrides, decorators — and builds
nothing, so unlike `checkGraph` it is safe anywhere in a test. `expectGraphSnapshot` compares it with
a file kept next to the tests:

```dart
test('the graph keeps its shape', () async {
  final app = await cobaltTestScope(root: const AppScope(), rootName: 'app');
  expectGraphSnapshot(app, 'test/app_graph.snapshot');
});
```

```text
scope "app"
  Clock — lazySingleton
  Greeter — lazySingleton
  GreetingStore — lazySingleton, decorated: Logging
```

A change fails with a line diff. Rewrite the file with `COBALT_UPDATE_SNAPSHOTS=1` (or
`update: true`) and commit it. A missing snapshot fails too, rather than being written and passing.
The file part needs `dart:io` and is imported only where it exists, so the package keeps its web and
WebAssembly support; there, compare `describeGraph` with a string.

`expectGraphSnapshots(graphOf, environments: {...}, directory: ...)` keeps one snapshot per
environment and names each that moved. A line shows the class a key builds when its factory says —
`ApiClient — lazySingleton, as LiveApiClient`; the generator's factories always do — and a scope
lists what it adopted, the bootstrap steps a start ran. `describeGraphMermaid(scope)` draws the same
facts as a Mermaid flowchart for a README or a pull request.

## The rest

- `DisposeRecorder` — records teardown order. **Its log belongs to the recorder, not to the
  library**: teardown is not awaited, so a scope from one test can finish releasing while the next
  one runs, and a shared list would fail the wrong test. `value` and `factory` hand you a
  disposable; `record` is for a fixture of your own, which should capture the recorder when it is
  *built* so a late report lands in the test it came from.
- `CapturingObserver` — collects every event, built on Cobalt's own `CobaltRecordingObserver` so the
  wording comes from the runtime rather than a copy that drifts.
- `FnFactory`, `ValueFactory`, `AsyncFnFactory`, `FnParamFactory` — a factory from a closure,
  instead of declaring a class per stub, for each of the four registration shapes that take one.
