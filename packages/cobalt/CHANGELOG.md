## 0.1.2

- Removed a stray `RELEASING.md` that had been committed into this package's
  own directory by accident (alongside an unrelated fix, in the commit that
  introduced it) and shipped inside the 0.1.0 and 0.1.1 archives. It was an
  outdated, unreferenced copy of the repository's actual release checklist —
  not a file this package ever meant to carry.

## 0.1.1

- No code changes in this package. Republished in lockstep with the fix
  in `cobalt_lint` 0.1.1 — see its changelog. Lockstep is the whole
  versioning policy: a fix in one package still ships as a patch for all
  fifteen, because publishing a subset is what lets the set drift.

## 0.1.0

- `CobaltScope.runBuilder`, which marks the window a scope builder runs in so
  a failed resolution can say the registration may be further down `build()`.
- Documented the named-record form of a parameterized factory's argument,
  which keeps the argument names a positional record loses. Pinned by tests.
- `getAll` no longer sorts a copy of the matches on every call: registrations
  are already iterated in registration order, so the sort said the same thing
  at the cost of a list per call. About a third off its cost, order unchanged
  and now pinned by tests.
- `push` takes `observers`, added to the inherited ones, so a subtree can be
  watched without installing anything at startup.
- An async registration made once `init()` has started is refused rather than
  accepted and left unbuildable: phase 1 takes its list at the start and runs
  once, so such a registration could never be built. Sync registrations are
  unaffected.
- `dependsOn` naming something that is not an async registration fails `init()`
  with `CobaltDependsOnError` instead of being silently dropped. An async
  registration in an ancestor scope is still ignored, which is the one case
  where dropping the edge is right.
- The two parameterized-factory misuses have their own errors,
  `CobaltNotParameterizedError` and `CobaltParamRequiredError`, rather than a bare
  `CobaltError`.
- `CobaltNotRegisteredError` and `CobaltNotReadyError` carry the chain of
  registrations under construction when the key was asked for, as `resolving`
  and in the message. The chain is the synchronous one: an awaited build
  contributes nothing, because a parallel init level holds several branches at
  once and none of them called the others.
- Initial release.
- `CobaltScope`: a hierarchy of scopes, `O(1)` resolution, lazy and eager
  singletons, transients, named registrations, `getAll` and parameterized
  factories.
- Disposal is LIFO by **creation** order, not declaration order. Teardown is
  best-effort under a global deadline: a step that fails or times out is
  recorded in `CobaltDisposeError` and the rest still run.
- `CobaltApplication`: two-phase startup. Phase 0 runs `@CobaltBootstrap` steps
  before the container exists; the root scope adopts them, so a step holding a
  resource is released last.
- Kahn's algorithm layer by layer, so independent async initializers run
  concurrently through `Future.wait`. Cycles raise `CobaltCycleError` naming the
  path — at build time in generated code, and at runtime through
  `CobaltResolutionTracker` for hand-written factories.
- Observability without dependencies: `CobaltObserver` with typed events,
  `CobaltLogObserver` turning them into records, and sinks —
  `CobaltDeveloperLogSink`, `CobaltPrintLogSink`, `CobaltMultiSink`, and
  `CobaltLogSink.from` to adapt any logger in one line.
- A retained registration can name a `dispose` callback, so the scope can
  close a type that implements neither `Disposable` nor `AsyncDisposable` —
  a client from another package, say. `adopt` takes one too. Absent from
  `registerFactory` and `registerParamFactory`, which retain nothing.
- `CobaltResolver.getOrNull` resolves an optional dependency, returning null
  only when nothing is registered — "registered but not ready" still throws.
- `CobaltScope` gained four read-only members for diagnostics: `keys`,
  `visibleKeys` (mapped to the owning scope), `root` and `debugDescribeTree`.
  None of them throws on a scope that is being torn down.
- `getWithParam` checks the value against the parameter type the factory was
  registered with, raising `CobaltParamTypeError` naming the registration and
  both types, instead of a cast error from inside the factory. A subtype of the
  registered type is accepted.
- Fixed: the resolution tracker removed a key only from the top of its stack,
  so a registration in a parallel init level that finished before the one
  entered after it stayed behind. Because one tracker serves the whole scope
  tree, the next scope registering that key was told it was a cycle.
- `debugKindOf` and `debugResolve` answer by `CobaltKey` rather than by type
  argument, which is what lets a tool walk a whole graph — `get<T>` cannot be
  called from a loop over `keys`, since Dart has no way to turn a `Type` back
  into a type argument. `debugResolveWithParam` is the parameterized twin.
- `onInstanceCreated` reports the `CobaltRegistrationKind` it built, and
  `CobaltLogRecord` carries it alongside `retained`. The `retained` flag alone
  collapses five lifetimes into two, and it only ever existed inside the
  message text. An eager singleton still reports nothing: it is built by
  whoever called `registerSingleton`, so the scope has nothing to announce.

