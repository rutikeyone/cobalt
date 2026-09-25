# cobalt_test

Test helpers for [Cobalt](https://pub.dev/packages/cobalt): build and tear down graphs, override
dependencies, and check that a hand-written graph resolves.

Pure Dart, on `test_api` and `matcher` rather than the full `test` runner, so the same helpers work
under `dart test` and `flutter test`.

```yaml
dev_dependencies:
  cobalt_test: ^0.3.0
```

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
