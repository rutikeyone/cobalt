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
