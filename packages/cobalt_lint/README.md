# cobalt_lint

Analyzer plugin with lint rules for [Cobalt](https://github.com/rutikeyone/cobalt). It surfaces
invalid annotations in the IDE instead of only when `build_runner` runs.

```yaml
plugins:
  cobalt_lint: ^0.1.0
```

The `plugins` section only works at the root of a package or workspace — a nested
`analysis_options.yaml` is silently ignored, and `dart analyze <nested/dir>` will not apply it.

The plugin is resolved **from pub.dev, not from your pubspec**. The analysis server builds its own
`plugin_entrypoint` package and runs `pub upgrade` on it, so a `dependency_override` in your
`pubspec.yaml` has no effect on which `cobalt_lint` gets loaded. To point the server at local
sources — the only option against unpublished packages — name them inside the `plugins` section
itself:

```yaml
plugins:
  cobalt_lint:
    path: ../packages/cobalt_lint
  dependency_overrides:
    cobalt_lint:
      path: ../packages/cobalt_lint
    cobalt_analyzer:
      path: ../packages/cobalt_analyzer
```

### The second thing outside your pubspec

The synthetic `plugin_entrypoint` also depends on `analysis_server_plugin` at a version the **SDK**
chooses, not one you write. An SDK that vendors an unpublished version asks pub.dev for something
like `^0.3.21-dev`, finds nothing, and analysis fails before a single file is read:

```
Because plugin_entrypoint depends on analysis_server_plugin ^0.3.21-dev
which doesn't match any versions, version solving failed.
```

That case — an SDK vendoring a version pub.dev has never heard of — usually resolves itself once
that version is published. A related failure does not: `analysis_server_plugin` pins the analyzer
it depends on exactly, and `cobalt_lint` deliberately caps `analyzer` below 13.0.0 to keep working
on Flutter 3.38.9. An SDK whose bundled `analysis_server_plugin` needs an analyzer at or above that
makes the same crash permanent, not transitional — no future publication changes it, only a change
to `cobalt_lint`'s own analyzer range would, and that range is a deliberate floor, not an oversight.

Neither is a failure of the code being analysed, and neither is fixable from the plugin's side —
which is why this repository's own `analysis_options.yaml` does **not** enable the plugin, even now
that `cobalt_lint` is published. The block lives in `analysis_options.plugin.yaml`, copied over by
hand, and that split is permanent. The rules themselves are covered by this package's tests, which
drive them through `analyzer_testing` and never start a server.

The overrides above are gone from this repository's own copy now that `cobalt_lint` is published —
`analysis_options.plugin.yaml` carries the plain three-line form. What does not go away is the
`plugins:` line living in that separate file rather than in `analysis_options.yaml` itself.

## Rules

| Rule | Catches |
|---|---|
| `cobalt_missing_injection_mixin` | `@injected` fields without `with _$ClassName`, on a class the container registers |
| `cobalt_injected_field_needs_an_injectable` | `@injected` fields on a class the container never registers |
| `cobalt_param_needs_an_injectable` | `@CobaltParam` on a class the container never registers |
| `cobalt_injected_field_must_be_late_final` | `@injected` on a mutable, non-late or static field |
| `cobalt_injectable_must_be_constructible` | `@CobaltInject` on an abstract class or one with no public generative constructor |
| `cobalt_init_requires_init_method` | `@CobaltInit` on a class with no `init()` |
| `cobalt_bootstrap_requires_run_method` | `@CobaltBootstrap` on a class with no `run()` |
| `cobalt_bootstrap_step_cannot_inject` | a bootstrap step whose constructor takes required parameters |
| `cobalt_environment_needs_a_registration` | `@CobaltEnvironment` on a class nothing registers, where it silently does nothing |
| `cobalt_dependency_is_not_registered` | an injected dependency nothing in the package registers |
| `cobalt_dependency_cycle` | an injectable class that depends, eventually, on itself |
| `cobalt_registration_is_never_released` | a registered class with a `dispose()` or `close()` the scope cannot see |
| `cobalt_resource_is_never_closed` | A registration holds something closeable and offers no way to close it. |

All rules are warnings, so they are on by default. Every rule reads annotations through
`cobalt_analyzer`, the same layer the generator uses.

## Why the graph rules report less than the build does

`cobalt_registration_is_never_released` is the one that pays for itself in a Flutter application.
A scope releases what implements `Disposable` or `AsyncDisposable`, and Dart has no structural
typing — so `ChangeNotifier.dispose`, which matches the interface method exactly, is invisible to
it, and `Bloc.close` is not even the right name. The rule reports a registered class that declares
a teardown-shaped method (no required parameters, returning `void` or a `Future`) and neither
implements an interface nor names a `dispose:` function.

It stays quiet where the scope would never call one anyway: a transient and a parameterized
registration are not retained. It also stays quiet when a `Disposable` from somewhere else is in
the supertypes, because it matches by name rather than by library — a rule that cannot see the
whole graph should fail towards silence.

Eleven of the thirteen rules answer a question about one declaration. The other two —
`cobalt_dependency_is_not_registered` and `cobalt_dependency_cycle` — answer one about the whole
package, and the analysis server does not offer that view: it hands a rule one library at a time,
and the only synchronous window onto the others is their **parsed**, unresolved source.

So they share an index of what the package registers, read from syntax — `@CobaltInject` classes,
their `exposeAs` targets, `@CobaltModule` members (indexed by return type, with one `Future` layer
removed) and `@CobaltScopeRoot(provides: [...])` entries — together with what each registration
asks for. It holds bare names: no library, no type arguments, no `@Named` qualifier. Each of those
omissions makes the index match **more**, so the rule stays quiet where the build still objects:

| Case | Build | Rule |
|---|---|---|
| nothing registers `HttpClient` | error | reported |
| `@Named('audit') Logger` where only an unnamed `Logger` is registered | error | silent |
| `Repository<Order>` where only `Repository<User>` is registered | error | silent |
| two same-named classes from different libraries, one registered | error | silent |

That asymmetry is deliberate. A false report from an editor that cannot see the whole graph costs
more than a missed one, because the build is still there and is still exact. Treat the rules as the
fast path, never as the authority.

For a cycle the same coarseness cuts the other way, and needs the opposite care: a shared name
makes the graph *denser*, and a dense graph can grow a loop no real one has. So a name two
declarations in the package both claim is dropped from the graph rather than fused, and every
registration on the loop is reported — each is a place the loop could be broken. Only one loop is
reported at a time, which is what the build does with the same graph.

The index is rebuilt when a file in `lib` changes, and checked by modification stamp otherwise —
listing costs a stat per file, building costs a parse per file. If any file will not parse, the
rule reports nothing at all rather than mistake a skipped file for a missing registration.

Manual Mode is out of reach for the same reason it is out of reach for the generator: a
hand-written factory resolves inside `create`, and nothing static can see what it will ask for.

## Why `@injected` has two rules

They look like one question and are two, with different answers. On a class the container registers,
the mixin exists and the fix is to mix it in — `cobalt_missing_injection_mixin`. On a class it does
not, no mixin is written for it at all, so `with _$ClassName` sends you to a name that will never be
generated; the fix is to annotate the class or drop `@injected`, which is
`cobalt_injected_field_needs_an_injectable`.

Both use the same reading of "registers" the generator does — `@CobaltInject` and `@CobaltInit` alike.
`cobalt_param_needs_an_injectable` is the same shape for `@CobaltParam`: on a class the container does
not know, the marking is read by nobody and the class is constructed by hand exactly as before.
