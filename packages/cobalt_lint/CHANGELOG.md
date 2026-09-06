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
