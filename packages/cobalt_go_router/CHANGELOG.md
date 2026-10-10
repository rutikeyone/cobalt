## 1.4.0

- No code changes in this package. Republished in lockstep with 1.4.0:
  constructor defaults, `exposeAs` with `instantiations` and `CobaltRoot`
  in `cobalt_generator`, build time without dependencies in `cobalt` and
  `cobalt_inspector`, and recipes in the docs.

## 1.3.0

- No code changes in this package. Republished in lockstep with 1.3.0:
  `cobalt_generator` supports `@injected` fields on generic classes, and
  `cobalt_lint` checks the instantiations of a generic class.

## 1.2.0

- No code changes in this package. Republished in lockstep with 1.2.0:
  `cobalt` reads its graph through a stable API, `cobalt_generator`
  registers generic classes, and `cobalt_lint` has quick fixes.

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

- No code changes in this package. Republished in lockstep with 0.9.0 — the
  last release before 1.0 — which makes `CobaltHook` a base class with
  `onReleased` (breaking), adds a timeout to `init`, a snapshot per
  environment and a Mermaid picture of the graph, a lint for a hook added too
  late, and a graph that restarts on a hot reload that changed it — see
  `cobalt`'s changelog.

## 0.8.0

- No code changes in this package. Republished in lockstep with 0.8.0, which
  adds hooks on a supertype, makes every Cobalt error `final` (breaking) and
  stops a log observer from formatting the records it drops — see `cobalt`'s
  changelog.

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

- No code changes in this package. Republished in lockstep with 0.5.0, which
  adds async transients, decorators of every registration of a type and
  `@injected` fields on decorator classes — see `cobalt`'s changelog.

## 0.4.0

- Supports go_router 18 (`">=17.0.0 <19.0.0"`). go_router 18 requires
  Flutter 3.44; on the 3.38 floor the resolver keeps 17.

## 0.3.0

- `overrides` on `CobaltRouteScope`, `CobaltShellRoute`, `cobaltShellRoute`,
  both `CobaltStatefulShellRoute` constructors and `CobaltStatefulShellBranch`.
  On a route it is a `CobaltRouteOverrides`, built from the route state each
  time the flow's scope is created — on entry and again when `identity`
  changes.

## 0.2.1

- No code changes in this package. Republished in lockstep with the toolchain
  packages, which now accept analyzer 13 and 14 — see `cobalt_generator`'s
  changelog.

## 0.2.0

- No code changes. The README no longer says a flow of top-level routes
  cannot be scoped: a `ShellRoute` has no path, so `/cart`, `/checkout` and
  `/payment` under one `CobaltShellRoute` keep their URLs and share one scope.
  Pinned by a test; what is still out of reach is written down instead.
- Republished in lockstep with lazy async singletons and overrides in `cobalt`
  0.2.0 — see its changelog.

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
- `CobaltShellRoute` (a `ShellRoute` subclass, plus the `cobaltShellRoute()`
  function form): a scope that lives exactly as long as a navigation flow is
  open. Navigating inside the flow keeps it; leaving disposes it. No router
  listener is involved — ownership is the widget tree's.
- `identity` re-creates the scope when the flow's subject changes, which is
  needed because go_router keys a shell page by the route object's identity and
  would otherwise reuse the same state across `/order/1` and `/order/2`.
- `CobaltStatefulShellRoute` and `CobaltStatefulShellBranch` for tabs, mirroring
  `StatefulShellRoute` including its `.indexedStack` constructor.
- Documented limits: a branch is kept **alive**, not **visible**, so switching
  tabs disposes nothing; and a branch's initial route cannot be
  parameterized — go_router asserts on it.
