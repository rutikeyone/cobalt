## 0.2.0

- Lazy async singletons. `registerLazyAsyncSingleton<T>(factory)` registers
  something built by the first `getAsync<T>()` rather than during `init()` —
  for what lives as long as the scope but few screens want. Concurrent calls
  share one build; a failed build is not remembered, so the next call
  retries; the instance is retained and released in creation order. It may be
  registered after `init()`.
- `getAsync<T>()` and `getAllAsync<T>()` on `CobaltResolver` and
  `CobaltScope`. `getAsync` on an async singleton `init()` is still building
  waits for it — except from inside that same `init()`, where it throws
  `CobaltNotReadyError` as `get` does, because waiting could never end.
- `CobaltLazyAsyncError` when a lazy registration is read synchronously
  before it is built — by `get`, `getOrNull` or `getAll`.
- A lazy build that asks, through its own chain, for the key it is building
  throws `CobaltCycleError` with the path instead of deadlocking. The chain
  is carried per call in a `Zone`, so a key another caller is building is
  waited for rather than reported as a cycle.
- `dispose` waits for lazy builds in flight under the same deadline
  (`CobaltDisposeStage.awaitingLazyBuild`); one that finishes after the
  deadline is closed as soon as it arrives. A lazy build that threw does not
  make `dispose` throw — `CobaltDisposeFailure.isBuildFailure`.
- `dependsOn` naming a lazy registration fails `init()` with
  `CobaltDependsOnError`.
- `debugResolveAsync(CobaltKey)`, and `CobaltRegistrationKind.lazyAsyncSingleton`
  from `debugKindOf`.
- Overrides. `CobaltOverride<T>.value`, `.lazy` and `.transient`, and
  `CobaltParamOverride<T, P>`, handed to `CobaltScope.root`, `push` or
  `CobaltApplication.start` as `overrides:`. Each is registered first, in the
  scope it is given to, and the real registration of its key is then skipped
  rather than rejected as a duplicate — so every factory in the scope that
  owns the key resolves the replacement, which a registration shadowed from a
  child scope cannot do. A value handed to `registerSingleton` under an
  override is still owned and closed; a `dependsOn` naming an overridden key is
  satisfied.
- `CobaltOverrideError`: an override without a type argument inside the list,
  where Dart infers `Object`, is refused on creation; one that no registration
  claims fails `runBuilder`, naming the ancestor that owns the key when there
  is one.
- `onRegistrationOverridden` on `CobaltObserver`, a record at `info` from
  `CobaltRecordingObserver`, and `overriddenKeys` on the scope.
- `registerEagerSingleton(factory)`: builds now, inside the scope, so the
  instance is reported to observers, a failed resolution names its chain, and
  an override means the factory never runs.
- **Breaking:** `CobaltRegistrationKind`, `CobaltDisposeStage` and
  `CobaltEventKind` each gained a value, so an exhaustive `switch` over any of
  them needs a new case, and `CobaltResolver` gained two methods for anything
  implementing it.

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

