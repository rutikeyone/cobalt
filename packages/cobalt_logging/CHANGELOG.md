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
