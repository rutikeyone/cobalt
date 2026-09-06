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
