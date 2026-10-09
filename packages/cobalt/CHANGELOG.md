## 1.3.0

- No code changes in this package. The Example tab opens with the Flutter
  app from the Quick start (`examples/hello`), followed by Manual Mode in
  pure Dart.

## 1.2.0

- A stable API for reading a scope's graph. `registrationOf(key)` returns
  a `CobaltRegistrationInfo`: kind, implementation, decorators and whether
  it is overridden. `previewRegistrations(builder)` lists what a builder
  registers without starting anything, `hooks` returns `CobaltHookInfo`s,
  `adoptedTypes` the types handed to `adopt`, and `describeTree()` the tree
  as text. Unlike the `debug*` members, these are covered by semver.
- Deprecated: the read-only `debug*` members, `debugKindOf`,
  `debugDecoratorsOf`, `debugRegistrationsOf`, `debugImplementationOf`,
  `debugAdopted`, `debugHooks` and `debugDescribeTree`. Each deprecation
  names its replacement; they work unchanged until 2.0 removes them.
  `debugResolve` and its three siblings stay `@experimental`.
- `CobaltNotRegisteredError` ends with a hint: the scopes below or beside
  this one that register the key (`registeredElsewhere`), the same type
  under other names (`sameType`), or, when neither applies, that nothing in
  the scope tree registers it.
- `@CobaltInject(instantiations: [...])`, re-exported from
  `cobalt_annotations`, registers a generic class once per instantiation;
  `cobalt_generator` 1.2.0 writes the factories. Requires
  `cobalt_annotations` 1.2.0.
- The README opens with what Cobalt is, how to install it and a Quick
  start, and the pubspec description says what the package does.

## 1.1.1

- Every runtime error ends with a link to its entry in
  `docs/TROUBLESHOOTING.md`, which says when the error happens and what to
  do. Only `toString()` changes; `message` is the same as before.
- Documentation for newcomers: a shorter README with a Quick start,
  `examples/hello` as the smallest app, `docs/OVERVIEW.md` for everything the
  README no longer holds, and `docs/TROUBLESHOOTING.md`, one entry per error.

## 1.1.0

- Korean documentation: README, both guides and MIGRATION are available in
  Korean (`README.ko.md`, `GUIDE_MANUAL.ko.md`, `GUIDE_CODEGEN.ko.md`,
  `MIGRATION.ko.md`) and link to the other languages. No code changes in this
  package.

## 1.0.0

The API is stable: from here on, only a major release breaks it. The README's
Compatibility section says what that covers; coming from an older 0.x,
MIGRATION lists every change that stops code compiling.

- `CobaltScope`'s `debug*` members — `debugKindOf`, `debugDecoratorsOf`,
  `debugRegistrationsOf`, `debugImplementationOf`, `debugAdopted`,
  `debugHooks`, `debugResolve` and its three siblings, `debugDescribeTree` —
  are `@experimental`: they are how the inspector and `cobalt_test` read the
  graph, and they may change in a minor release. Newer analyzers report
  `experimental_member_use` where code in another package calls them.

## 0.9.0

The last release before 1.0: what could not change after it without a major
release is settled here.

- **Breaking:** `CobaltHook<T>` is an `abstract base class` with empty
  methods, as `CobaltObserver` is. A hook is `final class … extends
  CobaltHook<T>` and overrides what it needs; a new method is a minor change
  from 1.0 on.
- `CobaltHook.onReleased(instance)`: when the scope is disposed, every
  instance it kept comes back through the hooks it passed — innermost first,
  in the reverse of the order they were built, before the instance is
  closed — so what joined a registry can leave it. A transient never comes
  back. A throw is a teardown failure. A graph without hooks pays nothing.
- `init(timeout:)` and `CobaltApplication.start(initTimeout:)`: past the
  budget, init throws `CobaltInitTimeoutError` naming every async singleton
  not yet built, observers hear `onScopeInitFailed`, and `start` disposes the
  root. Builds in flight run to the end and are closed as they arrive; no
  later level starts. Without a timeout nothing changes.
- `CobaltDescribedFactory`, a factory that names the class it builds;
  `CobaltScope.debugImplementationOf(key)` and `debugAdopted` — what
  `describeGraph` needs to tell `FakeApiClient` from `LiveApiClient` behind
  one `ApiClient`, and to list the bootstrap steps a start ran.
- `CobaltScope.debugRegistrationsOf(builder)`: the keys a builder registers
  and their lifetimes, run without building anything — an eager
  registration is recorded, not built.

## 0.8.0

- **Breaking:** `CobaltError` is a `base class` and every error —
  `CobaltNotRegisteredError`, `CobaltCycleError` and the rest — is `final`.
  Catch them; don't implement or extend them. What it buys: a new field on
  an error is a minor change from 1.0 on.
- Hooks. `CobaltHook<T>` and `CobaltScope.hookAll<T>(hook, debugLabel:)` run
  on every `T` the scope, or any scope below it, builds — whichever
  registration built it — and hand the instance on unchanged: what a
  decorator cannot do for a supertype, since a wrapper of `Loggable` is not
  the `Api` the registration promised. A hook sees what the factory made,
  before decorators, for every kind of registration, and not a value handed
  over with `registerSingleton`; ancestors' hooks run first; one that throws
  fails the call. Adding one after the scope, or one below, has built
  anything throws the new `CobaltHookError`. `debugHooks` lists a scope's
  own.
- `CobaltRecordingObserver.accepts(level)`, asked before a record is made:
  `onRecord` never sees a record it turned down, and its message is never
  formatted. `CobaltLogObserver` answers it from `minimumLevel`, so the
  per-instance records it drops by default cost nothing — a build with a log
  attached at the default level went from 1.61 µs to 817 ns, what an
  observer that overrides nothing costs. A subclass that filtered in
  `onRecord` keeps working; overriding `accepts` makes it cheaper.

## 0.7.0

- **Breaking:** `CobaltResolver` is an `abstract base class`, and
  `CobaltScope` extends it. It can no longer be implemented or mocked outside
  Cobalt — which is what lets a new way of resolving arrive in a minor
  release from 1.0 on. A test that mocked the resolver builds a real scope
  instead: `cobaltTestRoot` from `cobalt_test` (see MIGRATION).
- `CobaltRegistrationKind.isRetained`, `takesParam`, `isAsync` and
  `isBuiltByInit` — the questions a tool asks of every kind, including kinds
  that do not exist yet. From 1.0 a new kind is a minor change: ask the
  getters rather than switching over the values.
- The README has a Compatibility section — what breaks from 1.0 on and what
  does not — and a Performance section, measured next to get_it.

## 0.6.0

- Build times. `CobaltObserver.onInstanceBuilt(scope, key, {kind, retained,
  took})` is called right after `onInstanceCreated` for the same build.
  `took` is the whole wall time from calling the factory to the instance
  being ready: the builds it resolved on the way, every `await` of an async
  factory and filling `@injected` fields are all in it. A separate event, so
  an observer written before it keeps compiling.
- `CobaltLogRecord.took`, and `took_us` in `toStructured()`.
- `CobaltRecordingObserver` writes its creation record from
  `onInstanceBuilt`, and its `onInstanceCreated` is now empty: still one
  record per build, in the same order, with a message that now ends with the
  build time — `built Api in "app" as lazySingleton in 340µs`. A subclass
  that overrode `onInstanceCreated` and called `super` for the record should
  move to `onInstanceBuilt`.

## 0.5.0

- Async transients. `registerAsyncFactory<T>(factory)` registers something
  built asynchronously that every caller wants fresh — a report assembled on
  request, a query opening its own connection. Every `getAsync` builds and
  awaits a new instance the scope does not keep, and calls at the same time
  do not share a build. It is never part of `init()`, so it may be
  registered afterwards; the build runs on the owning scope inside the lazy
  chain, so one that awaits its own key is a `CobaltCycleError` rather than a
  hang, and it is decorated on every build. `get`, `getOrNull` and `getAll`
  throw the new `CobaltAsyncTransientError` naming `getAsync`, and a
  `dependsOn` naming one is a `CobaltDependsOnError`. `CobaltOverride.transient`
  replaces one with a synchronous double.
- Decorators of every registration of a type. `decorateAll<T>(decorator)`
  wraps every registration of `T` in the scope, named or not, including one
  registered later. It shares one order with `decorate`: whatever wraps a key
  applies in the order it was added, the first innermost, whether it was
  added for the key or for its type. Refused like `decorate` — a key of `T`
  already resolved is `CobaltDecoratorError.late`, and a scope that registers
  no key of `T` is the new `CobaltDecoratorError.notOwnedType` from
  `runBuilder`, naming the nearest ancestor that registers the type.
  `debugDecoratorsOf` lists both kinds.
- **Breaking:** `CobaltRegistrationKind.asyncTransient`, so an exhaustive
  `switch` over it needs a new case.

## 0.4.0

- Async parameterized factories. `registerAsyncParamFactory<T, P>` registers
  something built asynchronously from a value only the call site knows — a
  document loaded by id — and `getAsyncWithParam<T, P>` awaits it. Every call
  builds a new instance the scope does not keep; it is never part of
  `init()`, so it may be registered afterwards. The build runs on the owning
  scope, may await lazy registrations, is decorated like any build, and a
  build that asks through its own awaits for the key it is building is a
  `CobaltCycleError` rather than a hang. `getAsyncWithParam` on an ordinary
  parameterized registration returns what `getWithParam` would.
- `CobaltAsyncParamFactory`, `CobaltAsyncParamOverride`, `CobaltAsyncParamError`
  (for `getWithParam` on one), `debugResolveWithParamAsync`, and
  `CobaltParamRequiredError` naming the async form.
- **Breaking:** `CobaltRegistrationKind.asyncParameterized`, and
  `getAsyncWithParam` on `CobaltResolver` for anything implementing it.

## 0.3.0

- Decorators. `CobaltScope.decorate<T>(CobaltDecorator<T>)` wraps what a
  registration hands out without touching its class — logging, retries, a
  cache, a metric around a client you do not own. Decorators apply in the
  order added, the first innermost, with the resolver of the scope that owns
  the registration. They apply when an instance is handed out, not when it is
  built: a retained registration is decorated once, on first resolution, and
  shared; a transient or parameterized one on every build. So the order of
  `decorate` and the registration inside a builder never matters, not even for
  an async singleton built by `init()`, and an override is decorated like the
  registration it replaced. The scope keeps owning the inner instance and
  closes it once; the decorator is never closed.
- `CobaltDecoratorError`: decorating a key someone already resolved — its
  holders would keep the undecorated instance — or one the scope does not
  register, reported by `runBuilder` with the ancestor that owns it. A
  decorator resolving its own key is a `CobaltCycleError`.
- `debugDecoratorsOf(CobaltKey)` names what wraps a key, innermost first, by
  the `debugLabel` passed to `decorate` or else the decorator's type.
- `warmUp(Iterable<CobaltKey>)` starts every lazy async build in the list at
  once and completes when all have settled. Every key is checked before
  anything is built; builds run on the owning scope and are the ones
  `getAsync` would share; failures do not stop the others and arrive together
  as a `CobaltWarmUpError` with a stack trace for each.

## 0.2.1

- No code changes in this package. Republished in lockstep with the toolchain
  packages, which now accept analyzer 13 and 14 — see `cobalt_generator`'s
  changelog.

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
- A list of overrides is checked before the scope exists, so a push refused
  for one leaves no half-built child in the tree.
- `CobaltApplication.start` disposes a root that fails to assemble or
  initialize before rethrowing. Before, the bootstrap steps it had adopted and
  everything it had built were never released — true of a failing `init()`
  since 0.1.0, and of an override that replaced nothing now.
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

