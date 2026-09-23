# cobalt_test_flutter

Widget-test helpers for [Cobalt](https://github.com/rutikeyone/cobalt). Add it as a `dev_dependency`.

```yaml
dev_dependencies:
  cobalt_test_flutter: ^0.2.0
```

Two functions, both written because reaching for the obvious call is wrong in a way that costs an
afternoon.

```dart
await tester.pumpWidget(const MyApp());
await settle(tester);

final app = mountedRootScope(tester);
expect(app.isRegistered<NoteStore>(), isTrue);
```

## `settle`

`pumpAndSettle` pumps until no frame is scheduled, and a `CircularProgressIndicator` in a `loading`
builder schedules them forever — so the obvious call hangs until the test times out.

Two pumps rather than one, because `CobaltScopeWidget` and `CobaltAppScope` publish the scope only
after `init()` completes: the first frame is the loading one, the graph is published during it, and
the second frame is the first that has anything to find. Nested scopes cost a call each — an outer
flow publishes, and only then does the inner one mount.

## `mountedRootScope`

The graph a mounted application owns, which is harder to reach by hand than it looks. This
repository got it wrong four separate times, in two different ways.

**Where to read from.** The provider is published *inside* `MaterialApp`, below its builder, so a
context taken from the `MaterialApp` itself sits above it and finds nothing at all.

**Which scope you get.** A screen that owns a scope publishes a provider of its own, so the nearest
one is the screen's rather than the application's — and a test looking for what the graph registered
finds the screen's registrations instead.

It reads the published widget rather than looking one up from a context, because
`CobaltScopeProvider.of` searches *above* the element it is given and would skip the very provider
that was found.

## Why this is not in `cobalt_test`

`cobalt_test` is pure Dart on `test_api` and `matcher`, so its graph helpers work under `dart test`
as well as `flutter test`, and nothing that only builds a graph has to depend on `flutter_test`.
Anything taking a `WidgetTester` needs it, and Dart has no optional dependencies — so it lives here.
The same reasoning splits `cobalt` from `cobalt_flutter`.
