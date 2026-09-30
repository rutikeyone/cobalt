## 0.8.0

- `@CobaltHookAll` / `@cobaltHookAll`: adds the annotated `CobaltHook<T>` to
  the generated root scope, with `order` among several.

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

- `@CobaltDecorates(Target, allNames: true)` wraps every registration of
  `Target`, whatever its name. It cannot be combined with `name:`.
- `@cobaltTransient` (or `lifetime: CobaltLifetime.transient`) next to
  `@CobaltInit`, and on a module member returning a `Future`, now means an
  async transient built by every `getAsync`. It used to be ignored.

## 0.4.0

- `@CobaltParam` on an `@CobaltInit` class makes it an async parameterized
  factory, built by each `getAsyncWithParam`. It used to be refused.

## 0.3.0

- `@CobaltDecorates(Target, {name, order})`: the generated form of
  `CobaltScope.decorate`. The class implements `Target` and takes the wrapped
  instance in its constructor; `order` says which of several wraps which.

## 0.2.1

- No code changes in this package. Republished in lockstep with the toolchain
  packages, which now accept analyzer 13 and 14 — see `cobalt_generator`'s
  changelog.

## 0.2.0

- `@CobaltInit(lazy: true)`, and the shorthand `@cobaltLazyInit`: the class is
  built by the first `getAsync` instead of during `scope.init()`.
- `@CobaltInject(lazyInit: true)` — the same for a `@CobaltModule` member
  returning a `Future`.

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

- An optional `@CobaltParam` parameter is refused: the record the call site
  passes carries no defaults, so the default could never be used.
- `@CobaltParam` marks a constructor parameter the call site supplies rather
  than the graph.
- Initial release.
- Annotations shared by the generator and the lint plugin, with no runtime and
  no analyzer dependency: `@CobaltInject` (plus the `@cobaltInject` /
  `@cobaltSingleton` / `@cobaltTransient` shorthands), `@Injected`, `@Named`,
  `@CobaltBootstrap`, `@CobaltInit`, `@CobaltScopeRoot` and `@CobaltEnvironment`.
- `CobaltEnvironment.matches` lives here rather than in the runtime: it is pure
  logic over strings, and both generated and hand-written code need it.
- `@CobaltScopeRoot(provides: [...])` and `CobaltProvided` declare registrations
  the generator cannot see, so its completeness check does not report them
  missing.
- `@CobaltModule` marks a class whose members register types the package does
  not own, and `@CobaltInject` gained `dispose` for closing them.
