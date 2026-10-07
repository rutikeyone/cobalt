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

- No code changes in this package. Republished in lockstep with 0.4.0, which
  adds async parameterized factories and go_router 18 support — see
  `cobalt`'s changelog.

## 0.3.0

- No code changes in this package. Republished in lockstep with 0.3.0, which
  adds decorators, overrides on widget and route scopes, and warm-up — see
  `cobalt`'s changelog.

## 0.2.1

- No code changes in this package. Republished in lockstep with the toolchain
  packages, which now accept analyzer 13 and 14 — see `cobalt_generator`'s
  changelog.

## 0.2.0

- No code changes in this package. Republished in lockstep with lazy async
  singletons and overrides in `cobalt` 0.2.0 — see its changelog. A minor version in `0.x`
  is a breaking one, so every internal constraint moves to `^0.2.0` together.

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
- An `CobaltLogSink` writing into `package:logging`, which has no notion of a
  record type of its own.
- Note the neighbour package `cobalt_logger`, one letter apart, which adapts a
  different logger.
