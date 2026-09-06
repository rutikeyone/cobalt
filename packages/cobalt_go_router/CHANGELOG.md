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
