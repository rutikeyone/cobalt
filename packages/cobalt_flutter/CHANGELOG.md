## 1.4.0

- No code changes in this package. The README starts the app with
  `CobaltRoot`.

## 1.3.0

- No code changes in this package. The README Quick start says why
  `cobalt` is a direct dependency and that `test/widget_test.dart` goes,
  points to what the editor shows before the first build, and opens with a
  GIF of the gallery.

## 1.2.0

- On a hot reload, `CobaltAppScope` compares the builder's registrations
  with the live graph through `CobaltScope.previewRegistrations` and
  `registrationOf` instead of the deprecated `debug*` members. It restarts
  the graph in the same cases as before. Requires `cobalt` 1.2.0.
- The README opens with what the package is, how to install it and a Quick
  start, and the pubspec description says what it does.

## 1.1.1

- `CobaltNoScopeError` and `CobaltNoAppScopeError` end with a link to their
  entry in `docs/TROUBLESHOOTING.md`, as every Cobalt error now does. No
  other changes in this package.

## 1.1.0

- No code changes in this package. Republished in lockstep with 1.1.0, which
  adds Korean to the inspector and to the documentation.

## 1.0.0

- The API is stable: from here on, only a major release breaks it — see
  Compatibility in the README. No code changes in this package since 0.9.0;
  coming from an older 0.x, MIGRATION lists what to change.

## 0.9.0

- A hot reload that changes the graph restarts it.
  `CobaltAppScope(restartOnGraphChange:)`, on by default and on the builder
  too, runs `root` again without building on every reload and compares its
  registrations with the live root's: a key added, removed or given another
  lifetime calls `restart()` and says what changed in the debug console; any
  other reload keeps the graph and everything below it. Not for
  `CobaltAppScope.start`, and `bootstrap` is not compared.
- `CobaltAppScope(initTimeout:)` and its builder: a start that hangs becomes
  the `errorBuilder` screen with a `CobaltInitTimeoutError` naming what never
  finished.

## 0.8.0

- **Breaking:** `CobaltNoScopeError` and `CobaltNoAppScopeError` are `final`,
  like every error in `cobalt` 0.8.0: catch them, don't implement or extend
  them.

## 0.7.0

- No code changes in this package. Republished in lockstep with 0.7.0, which
  makes `CobaltResolver` a base class (breaking), adds getters to
  `CobaltRegistrationKind` and lets the inspector open on a chosen tab — see
  `cobalt`'s changelog.

## 0.6.0

- No code changes in this package. Republished in lockstep with 0.6.0, which
  adds build times to observers and the inspector, a graph snapshot in
  `cobalt_test` and a lint rule — see `cobalt`'s changelog.

## 0.5.0

- No code changes. `context.cobaltAsync` documents that an async transient is
  built anew by every call, so the future belongs outside `build`.

## 0.4.0

- `context.cobaltAsyncWithParam<T, P>(param)`.

## 0.3.0

- `overrides` on `CobaltScopeWidget`, and an `overrides` getter on
  `CobaltScopedWidget` and `CobaltScopedStatefulWidget`. A function called on
  every mount, as on `CobaltAppScope`, so a remount never gets a value the
  previous scope already closed. It replaces what that scope registers; an
  override of a key an ancestor owns fails naming the owner.
- `CobaltAppScope(warmUp: [...])` — also on `.start` and `.builder` — starts
  building lazy async registrations as soon as the graph is up, behind the app
  rather than behind `loading`. A failure goes to `FlutterError.reportError`.
- Fixed: a builder that threw on a widget-owned scope, or an override that
  replaced nothing, left the pushed child in the tree with nobody to close it.
  The error now reaches `errorBuilder` and the half-built scope is disposed.

## 0.2.1

- No code changes in this package. Republished in lockstep with the toolchain
  packages, which now accept analyzer 13 and 14 — see `cobalt_generator`'s
  changelog.

## 0.2.0

- `CobaltAsyncBuilder<T>`: resolves with `getAsync` and builds from the result,
  showing `loading` meanwhile and `errorBuilder` (with `retry`) on failure.
  Something already built renders without a frame of `loading`. The
  resolution is held in state, so a parent rebuild neither restarts it nor
  retries a failed one by itself.
- `context.cobaltAsync<T>()`.
- `CobaltAppScope` and `CobaltAppScope.builder` take `overrides:` — a function,
  like `bootstrap`, called on every start and restart, so a restart does not
  get back a value the previous graph already closed.

## 0.1.2

- No code changes in this package. Republished in lockstep with a
  packaging fix in `cobalt` 0.1.2 (a stray file removed from its
  archive) — see its changelog. A fix in one package still ships as a
  patch for all fifteen, because publishing a subset is what lets the
  set drift.

## 0.1.1

- No code changes in this package. Republished in lockstep with the fix
  in `cobalt_lint` 0.1.1 — see its changelog. Lockstep is the whole
  versioning policy: a fix in one package still ships as a patch for all
  fifteen, because publishing a subset is what lets the set drift.

## 0.1.0

- `CobaltNoScopeError` and `CobaltNoAppScopeError` replace the bare `CobaltError`
  the two lookups used to throw, so a caller can catch the one it means. The
  first also explains the pushed-route case in its message.
- Initial release.
- `CobaltAppScope`: owns the root scope for the whole app. It builds the graph
  inside `runApp`, shows loading and error states with retry, exposes
  `restart()`, and disposes the root on unmount. Because it re-keys the
  provider, the subtree rebuilds against the new root after a restart.
- `CobaltScopeWidget`: a child scope whose lifetime is a widget's lifetime.
- `CobaltScopeProvider` and `context.cobalt<T>()`, plus `CobaltScopedWidget` and
  `CobaltScopedStatefulWidget` as bases.
- `disposeOnExitRequest` is opt-in and only meaningful on macOS and Linux,
  where `onExitRequested` fires and the exit is actually cancellable.
