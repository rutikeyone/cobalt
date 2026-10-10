## 1.4.0

- No code changes in this package. The README starts the app with
  `CobaltRoot`.

## 1.3.0

- No code changes in this package. The Example tab links to
  `examples/testing_patterns`.

## 1.2.0

- Reads the graph through `cobalt`'s stable introspection API
  (`registrationOf`, `hooks`, `adoptedTypes`) instead of the deprecated
  `debug*` members. What `checkGraph`, `describeGraph` and
  `describeGraphMermaid` report is unchanged. Requires `cobalt` 1.2.0.
- The README opens with how to install it and a first test.

## 1.1.1

- No code changes in this package. Republished in lockstep with 1.1.1:
  a shorter README with a Quick start, `examples/hello` as the smallest
  app, `docs/OVERVIEW.md` for everything the README no longer holds, and
  `docs/TROUBLESHOOTING.md`, one entry per error.

## 1.1.0

- No code changes in this package. Republished in lockstep with 1.1.0, which
  adds Korean to the inspector and to the documentation.

## 1.0.0

- The API is stable: from here on, only a major release breaks it — see
  Compatibility in the README. No code changes in this package since 0.9.0;
  coming from an older 0.x, MIGRATION lists what to change.

## 0.9.0

- `expectGraphSnapshots(graphOf, environments:, directory:)`: one snapshot
  per environment, every one checked before failing, the failure naming
  each that moved.
- `describeGraph` shows the class a key builds when its factory says and it
  is not the key's own type — `as LiveApiClient` — and what a scope adopted,
  the bootstrap steps a start ran. A hand-written graph without either reads
  as before; a generated one gains those lines, since the generator's
  factories now say.
- `describeGraphMermaid(scope)`: the same facts as a Mermaid flowchart.
- `FnHook` is a base class extending `CobaltHook`, with an optional
  `release` callback.

## 0.8.0

- `describeGraph` shows the hooks each scope adds, as `hooks: Label on Type`
  above its keys. A graph without hooks reads exactly as before, so existing
  snapshots stay valid.
- `FnHook`, the sibling of `FnDecorator` for `CobaltScope.hookAll`.

## 0.7.0

- `checkGraph` asks `CobaltRegistrationKind`'s getters instead of switching
  over the kinds. No behaviour change.
- With `CobaltResolver` a base class in `cobalt` 0.7.0, a resolver can no
  longer be mocked; `cobaltTestRoot` is the replacement.

## 0.6.0

- A snapshot of the graph. `describeGraph(scope)` renders what each scope
  registers — kind, overrides, decorators, child scopes nested — and builds
  nothing, unlike `checkGraph`. `expectGraphSnapshot(scope, path)` compares
  it with a file kept next to the tests: a change fails with a line diff,
  `COBALT_UPDATE_SNAPSHOTS=1` or `update: true` rewrites the file, and a
  snapshot that does not exist yet fails rather than being written and
  passing. The file part is imported only where `dart:io` exists, so the
  package keeps its web and WebAssembly support.

## 0.5.0

- `checkGraph` builds an async transient through `getAsync` and disposes it
  like a transient.

## 0.4.0

- `AsyncFnParamFactory`, and `checkGraph` builds an async parameterized
  registration from the sample value in `params:`.

## 0.3.0

- `FnDecorator<T>`: a decorator from a function, for tests that wrap a
  registration without declaring a class.

## 0.2.1

- No code changes in this package. Republished in lockstep with the toolchain
  packages, which now accept analyzer 13 and 14 — see `cobalt_generator`'s
  changelog.

## 0.2.0

- `checkGraph` builds lazy async registrations through `getAsync`, so they are
  checked like the lazy singletons beside them.
- `cobaltTestScope`, `cobaltTestRoot` and `pushForTest` take `overrides:`.

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

- Initial release.
- `cobaltTestScope` / `cobaltTestRoot` build a graph and dispose it with the
  test; `pushForTest` does the same for an override scope.
- `checkGraph` / `expectGraphResolves` resolve everything a scope can see and
  report every hole at once. This is the only way to check a hand-written
  graph, since a factory never declares what it will ask for. It is terminal:
  resolving is the check, so afterwards every lazy singleton is built.
- `ownerOf<T>` names the scope that owns a registration, which is what decides
  whether an override will actually be seen.
- `DisposeRecorder` keeps its log per instance rather than globally, because
  teardown is not awaited and a shared list fails the wrong test.
- `CapturingObserver`, plus `FnFactory` / `ValueFactory` / `AsyncFnFactory` /
  `FnParamFactory`.
- `DisposeRecorder.record` reports a teardown for a fixture the recorder did not
  build. Both it and `FnParamFactory` were found by the first packages to
  actually use this one — the helpers covered what they could supply, not what a
  test writes for itself.
