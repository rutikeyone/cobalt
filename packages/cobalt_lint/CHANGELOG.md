## 1.0.0

- The API is stable: from here on, only a major release breaks it — see
  Compatibility in the README. No code changes in this package since 0.9.0;
  coming from an older 0.x, MIGRATION lists what to change.

## 0.9.0

- New rule, `cobalt_hook_added_too_late`: `hookAll` after something that
  builds on the same scope — an eager registration, `get` and the other
  reads, `init`, `warmUp` — in an earlier section of the same cascade or an
  earlier statement of the same block on the same variable. The scope
  refuses it at runtime with `CobaltHookError`; the rule moves that into the
  editor. Eighteen rules.

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

- New rule, `cobalt_async_transient_read_synchronously`: `get`, `getOrNull`
  or `getAll` on a `CobaltResolver` or `CobaltScope`, or `context.cobalt` /
  `cobaltAll`, reading an async transient — which always throws
  `CobaltAsyncTransientError`. The type argument may be written or inferred.
  Async transients only: a lazy async singleton is read with `get`
  legitimately once `getAsync` or `warmUp` has built it. Seventeen rules.

## 0.5.0

- `cobalt_lazy_registration_injected_synchronously` and
  `cobalt_depends_on_lazy_registration` see async transients — a transient
  lifetime next to `@CobaltInit`, or on a module member returning a `Future`
  — and their messages say so.
- `cobalt_missing_injection_mixin` covers `@CobaltDecorates` classes, and
  `cobalt_injected_field_needs_an_injectable` no longer reports them; a
  decorator's `@injected` fields are edges of its target, so a loop through
  one is a `cobalt_dependency_cycle`.

## 0.4.0

- The graph rules see decorators: `cobalt_dependency_is_not_registered`
  reports a decorator whose target or dependency nothing registers,
  `cobalt_dependency_cycle` a loop through a decorator, and
  `cobalt_lazy_registration_injected_synchronously` a decorator taking a lazy
  registration.
- An async class built from a call-site value may take a lazy dependency; the
  lazy rule no longer reports it.

## 0.3.0

- `cobalt_override_needs_type_argument`: a `CobaltOverride` or
  `CobaltParamOverride` written without its type argument, which Dart then
  infers as `Object` inside a list or as the replacement's type on its own —
  either way the override replaces nothing.
- `cobalt_depends_on_lazy_registration`: `@CobaltInit(dependsOn: [...])`
  naming a lazy async registration, which `init()` never builds. Read from the
  package-wide index, like the other graph rules.
- Sixteen rules.
- The package index no longer calls `Folder.getChildAssumingFolder`, which
  analyzer 13.1 deprecated: under a fresh resolution the package itself
  failed `dart analyze --fatal-infos`. `getChild` exists and is current on
  every analyzer from 10 to 14.

## 0.2.1

- Accepts `analyzer` up to 14.x (`>=10.0.1 <15.0.0`, was `<13.0.0`), so the
  plugin resolves for SDKs whose `analysis_server_plugin` needs analyzer 13 or
  14. Flutter 3.38.9 stays the floor.
- The registration index no longer names AST classes that exist on only one
  side of analyzer 13 — `NamedExpression`, `DefaultFormalParameter`,
  `NormalFormalParameter` — and reads tokens and `childEntities` instead. The
  rules report exactly what they did; every test passes on analyzer 10.0.1,
  12.1.0, 13.3.0 and 14.4.0.

## 0.2.0

- `cobalt_lazy_registration_injected_synchronously`: a lazy async
  registration taken by a synchronous or eager async constructor, or held in
  an `@injected` field on any class — what the build refuses since 0.2.0,
  reported in the editor. A lazy module member counts; a name two
  declarations claim does not.
- The registration index read `@cobaltLazyInit` as no registration at all, so
  a class depending on one was reported by
  `cobalt_dependency_is_not_registered`. It is read like `@CobaltInit`.

## 0.1.2

- No code changes in this package. Republished in lockstep with a
  packaging fix in `cobalt` 0.1.2 (a stray file removed from its
  archive) — see its changelog. A fix in one package still ships as a
  patch for all fifteen, because publishing a subset is what lets the
  set drift.

## 0.1.1

- Fixed `cobalt_resource_is_never_closed` reporting a false positive on any
  field that is itself another retained Cobalt registration — a singleton,
  lazy singleton, or async singleton the scope already disposes on its own,
  independently of who holds a reference to it. The rule checked only whether
  a field's type offers a teardown-shaped method, with no regard for whether
  the scope already owns and closes that field's value through a separate
  registration; on 0.1.0 this fired on the ordinary shape of a dependency
  graph — any class taking a closeable dependency by constructor injection —
  not only on the leak it was written to catch. A field of a transient or
  parameterized registration is still reported, because the scope never
  retains those and nobody else is going to close them.

## 0.1.0

- `cobalt_resource_is_never_closed`: a registration that holds something
  closeable and offers no way to close it.
- Requires Dart `^3.10.0` — Flutter 3.38 — instead of `^3.13.0`, and moves
  `analyzer` to `>=10.0.1 <13.0.0`. The registration index was reading the
  analyzer 13 AST (`FormalParameter.type`, `NamedArgument`, `Folder.getFolder`,
  `ClassBody.members`); it now reads the model that spans the range. The old
  lower bound never compiled — `Folder.getFolder` arrived in 13.1, not 12.1.

- `cobalt_param_needs_an_injectable` reports `@CobaltParam` on a class nothing
  registers, where the marking does nothing at all.
- `cobalt_dependency_is_not_registered` and `cobalt_dependency_cycle` skip
  `@CobaltParam` parameters, which nothing registers and which close no cycle.
- `cobalt_injected_field_needs_an_injectable` reports `@injected` on a class the
  container never registers, where no mixin is generated and
  `cobalt_missing_injection_mixin` would have sent you to a name that does not
  exist. That rule now stays quiet there.
- Initial release.
- An `analysis_server_plugin` (not `custom_lint`, which is pinned to an
  incompatible analyzer) with nine warning rules, all reading annotations
  through `cobalt_analyzer` — the same layer the generator uses.
- `cobalt_dependency_is_not_registered` and `cobalt_dependency_cycle` answer
  whole-package questions the analysis server does not offer a view for, from a
  shared syntactic index of what the package registers and what each
  registration asks for. Both match on bare names, so they stay silent where
  the build still objects; see the README for the cases and why they fall that
  way. The cycle rule additionally drops any name two declarations both claim,
  because fusing two same-named types is how a graph with no loop grows one.
- Rules cover: an injectable that cannot be constructed, `@injected` fields
  that are not `late final`, a missing injection mixin, `@CobaltInit` without an
  `init` method, `@CobaltBootstrap` without a `run` method, a bootstrap step
  taking injected parameters, and `@CobaltEnvironment` on a class nothing
  registers.
- The analysis server resolves plugins from pub.dev rather than from your
  pubspec, so a `dependency_override` in `pubspec.yaml` does not affect which
  version loads. See the README for pointing it at local sources.
- The registration index reads `@CobaltModule` members too, so a graph using
  modules does not produce false reports.
- `cobalt_dependency_is_not_registered` skips optional dependencies. It walks
  them as a list rather than a set, because `CobaltTypeRef` compares by
  signature and would otherwise fold `Foo` and `Foo?` into one entry.
