## 0.1.1

- No code changes in this package. Republished in lockstep with the fix
  in `cobalt_lint` 0.1.1 — see its changelog. Lockstep is the whole
  versioning policy: a fix in one package still ships as a patch for all
  fifteen, because publishing a subset is what lets the set drift.

## 0.1.0

- Initial release.
- `CobaltBloc` — a mixin bridging `BlocBase.close` to Cobalt's
  `AsyncDisposable`, so the scope that built a bloc is the thing that closes
  it.
- `closeBloc` — the same reach for a class a mixin cannot touch, usable as
  `@CobaltInject(dispose: closeBloc)` and at a hand-written registration.
