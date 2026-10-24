<p align="center">
  <a href="COMPARISON.md">English</a> · <a href="COMPARISON.ru.md">Русский</a> · <a href="COMPARISON.zh-CN.md">中文</a> · <a href="COMPARISON.ko.md">한국어</a>
</p>

# Cobalt next to other packages

Which package to pick for the dependencies of a Dart or Flutter app, and when Cobalt is not the
answer. What this page says about other packages was checked on 2026-10-24 against pub.dev and
their documentation, for get_it 9.3.0, injectable 3.0.0, riverpod 3.4.3, provider 6.1.5+1 and
yx_scope 1.2.2. They move on, and the [sources](#sources) lead to their current state.

## In one line each

- **get_it** is a service locator: register once, `get` from anywhere. Nothing to generate, the
  most users, one stack of scopes.
- **injectable** writes get_it registrations from annotations.
- **riverpod** manages state, and its providers carry dependencies too, with lifetimes and
  overrides.
- **provider** puts objects into the widget tree.
- **yx_scope** builds containers by hand, with nested scopes the compiler checks.
- **Cobalt** is a container whose scopes form a tree and close what they built. The generator
  checks the graph when it runs, and code written by hand joins the same graph.

## Side by side

| | Cobalt | get_it | injectable | riverpod | provider | yx_scope |
|---|---|---|---|---|---|---|
| **Scopes** | a tree: any scope can have children, siblings included | one stack: `pushNewScope`, `popScope`, named scopes | get_it's stack: `@Scope` generates `init<Name>Scope` | one container; `ProviderScope` overrides for a subtree, `autoDispose` per provider | the widget subtree | containers nested to any depth; `ScopeHolder` creates and drops one |
| **Closing** | disposing a scope closes everything it built, newest first | `popScope` disposes the scope's objects in reverse registration order | `@disposeMethod`, `dispose:` | `ref.onDispose`; `autoDispose` once nothing listens | `dispose:` when the widget leaves | `drop` disposes the scope's dependencies |
| **A missing dependency** | fails `build_runner`, naming every gap; by hand, at the first `get` or in a test with `expectGraphResolves` | at the first `get` | a warning while generating; an error with `throwOnMissingDependencies: true` | nothing to register: a provider is a global declaration | `ProviderNotFoundException` at runtime | checked by the compiler: dependencies are fields of the container |
| **Code generation** | optional; generated and hand-written registrations share one graph | none | it is the generator | optional (`riverpod_generator`) | none | none |
| **Async start** | async singletons start in dependency order, independent ones in parallel, with a timeout | async singletons, `dependsOn`, `allReady()` | `@preResolve`: awaited before registration | `FutureProvider`; the order follows what each one awaits | `FutureProvider` widget | async dependencies, initialized with their scope |
| **Without Flutter** | yes | yes | yes | yes (`riverpod`) | no | yes (`yx_scope`) |
| **Swapping in tests** | an override replaces a registration where it lives; no global, so tests run in parallel | `allowReassignment`, `reset()`; one global `GetIt.I` by default | as get_it | overrides on `ProviderContainer` or `ProviderScope` | other providers around the widget | not described on its pub.dev page |
| **pub.dev likes / downloads in 30 days** | 5 / 1.6K | 4.7K / 2.4M | 1.5K / 396K | 4.0K / 4.1M | 11K / 1.1M | 72 / 8.6K |

## When Cobalt is not needed

- **Everything lives as long as the app.** No sign-out, no flow that owns state, a few services
  made in `main`: constructors or get_it do that with less.
- **The app already runs on riverpod.** Its providers have lifetimes and overrides already. A second
  container splits the graph in two, and each half has to know about the other.
- **You need a track record.** Cobalt reached 1.0 on 2026-09-30 and has few users so far, while
  get_it, provider and riverpod have years of answered questions behind them. Cobalt's API is stable
  since 1.0, and every minor release is checked for breaking changes, but that is a promise, not a
  history.
- **No code generator, and less to write than a scope builder.** Manual Mode is plain Dart, but it
  is still more than `registerSingleton`.

## When it pays off

- State belongs to a session, a flow or a screen, and has to be closed when that ends.
- Several services must start before the first frame, and some of them need others.
- A missing dependency should stop the build, not reach a user on some screen.
- Tests swap one dependency without a global, and run in parallel.

## Moving over

[MIGRATION.md](../MIGRATION.md) maps get_it, injectable, flutter_bloc and provider code to Cobalt
piece by piece, and lists what Cobalt does not have.

## Sources

Checked on 2026-10-24:
[get_it](https://pub.dev/packages/get_it) and
[its scopes](https://flutter-it.dev/documentation/get_it/scopes),
[injectable](https://pub.dev/packages/injectable) and
[`InjectableInit`](https://github.com/Milad-Akarie/injectable/blob/master/injectable/lib/src/injectable_annotations.dart),
[riverpod](https://pub.dev/packages/riverpod),
[provider](https://pub.dev/packages/provider),
[yx_scope](https://pub.dev/packages/yx_scope). Likes and downloads come from the pub.dev API
(`/api/packages/<name>/score`); for riverpod they are the `riverpod` package's, without
`flutter_riverpod`.
