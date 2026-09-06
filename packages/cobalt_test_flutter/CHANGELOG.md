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
- `settle` — the two pumps a starting graph needs. `pumpAndSettle` hangs on the
  indefinite animation a `loading` builder usually shows.
- `mountedRootScope` — the graph a mounted application owns, read from the
  published provider rather than looked up from a context, and climbed to the
  root so a screen that owns a scope does not answer instead.
