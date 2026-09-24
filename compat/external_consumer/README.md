# cobalt_external_consumer

A compatibility stand, not an example. It exists to answer one question the five
packages in `examples/` cannot: **does Cobalt work for a project that consumes it
the way a third party does?**

Every other member takes its siblings from a `pubspec_overrides.yaml` that
`tool/overrides.py` generates. This package deliberately does not: it names the
packages it uses in its own `dependency_overrides`, the way a project trying out
a local checkout would, and resolves with its own `pubspec.lock` and its own
`.dart_tool/package_config.json` — the same conditions a third-party project
gets.

## What it covers

One case per surface that could plausibly break from outside, not a small
application:

| Surface | Where |
|---|---|
| `@CobaltScopeRoot` | `lib/src/app_scope.dart` |
| `@CobaltBootstrap` + release on dispose | `lib/src/bind_platform.dart` |
| `@CobaltInject(exposeAs:)` | `lib/src/system_clock.dart` |
| `@CobaltInit` and `@CobaltInit(dependsOn:)` | `lib/src/database.dart`, `lib/src/search_index.dart` |
| property injection (`cobalt_property_injection` + `source_gen\|combining_builder`) | `lib/src/report.dart` |
| generic dependencies | `lib/src/repository.dart` |

`lib/cobalt.g.dart` is committed and verified by `git diff --exit-code` in CI,
the same way `examples/codegen_basics` is.

## What it does not prove

The source of the packages is substituted by `dependency_overrides`, so that the
stand tests this repository rather than the last release. So it proves that the
builders apply and the generated container works **from outside the packages**
— it does not prove resolution from pub.dev. Only a real publish does that.

## Two findings from building it

**1. The builders need nothing special.** All three are `auto_apply: dependents`,
and `CobaltContainerBuilder` collects IR with a package-scoped
`findAssets(Glob('lib/**.cobalt.json'))`. Declaring `cobalt_generator` in
`dev_dependencies` is the whole setup. This worked on the first run.

**2. The lint plugin does not read this package's pubspec.** The analysis server
builds a synthetic `plugin_entrypoint` package and runs `pub upgrade` on it
against pub.dev; `dependency_overrides` in `pubspec.yaml` are invisible to it.
Against unpublished packages that fails outright:

```
Because plugin_entrypoint depends on cobalt_lint any which doesn't exist
(could not find package cobalt_lint at https://pub.dev), version solving failed.
```

Hence the `dependency_overrides` block inside `analysis_options.yaml` — the same
scaffolding the repository root uses. A consumer of a *published* `cobalt_lint`
writes only the `plugins:` entry and needs none of it.

## Running it

```bash
dart pub get
dart run build_runner build
dart test
dart analyze .
```
