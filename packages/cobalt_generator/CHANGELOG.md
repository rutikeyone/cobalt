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

- Requires Dart `^3.10.0` — Flutter 3.38 — instead of `^3.13.0`, and moves
  `analyzer` to `>=10.0.1 <13.0.0` with `dart_style` to `>=3.1.6 <3.1.9`. The
  two formatters that range admits emit identical bytes for generated code, so
  no generated file changed; the floor job regenerates and diffs to keep that
  true.

- A nullable `@CobaltParam` keeps its `?` in the generated record. It used to
  be dropped, narrowing an argument the constructor was willing to take as
  null.
- A module member may take named parameters. They were refused because the
  emitter passed everything positionally; it no longer does. An optional
  parameter is still refused, for the reason it always was.
- A class with `@CobaltParam` parameters is generated as a parameterized
  factory, with a named record type emitted beside the container. Marked
  parameters are not dependencies: they are skipped by the completeness check
  and are no edge in the ordering.
- Constructors with named parameters are called the way they were declared.
  Every argument used to go in positionally, producing a file that did not
  compile.
- The `_$ClassName` injection mixin is written for every class the container
  registers, `@CobaltInit` included. Such a class used to be registered and left
  with its `@injected` fields unassigned.
- `@CobaltInit(dependsOn:)` naming a registration that is not itself `@CobaltInit`
  fails the build, listing every such edge at once.
- Two libraries in one package declaring classes of the same name no longer emit
  two factories of the same name. Every claimant of a contested base name gets a
  suffix from its own library; uncontested names are untouched, so the fix
  renames nothing in an existing file.
- Initial release.
- Three builders: `cobalt_property_injection` (per-file mixins via
  `SharedPartBuilder`), `cobalt_scan` (per-library IR to `.cobalt.json`, cached)
  and `cobalt_container` (aggregates every IR into `lib/cobalt.g.dart`).
  All are `auto_apply: dependents` — declaring the dev dependency is the setup.
- Emits named const factory classes, never closures, and orders registrations
  by a compile-time topological sort in which property-injected fields count as
  dependency edges.
- Import aliases come from a hash of the URL, so adding one import does not
  renumber the rest and produce a whole-file diff.
- Rejects a graph with a dependency nothing registers, listing every gap in one
  message and checking each environment separately. Registrations made by hand
  are declared through `@CobaltScopeRoot(provides: [...])`.
- Rejects at build time what would otherwise be silent: a dependency cycle, two
  registrations of one key whose environments overlap, and `@CobaltInject` on a
  class with type parameters.
- Generic types work as dependencies and as `exposeAs` targets:
  `Repository<User>` and `Repository<Order>` are separate registrations.
- Emits factories for `@CobaltModule` members, calling the member on a const
  module instance. Async ordering between module members is derived from the
  graph rather than declared.
- A nullable dependency is optional: it is emitted as `getOrNull` and skipped
  by the completeness check, while still ordering registration when the type
  is present. `@CobaltInit(dependsOn:)` is never optional, and a module member
  may not return a nullable type.
