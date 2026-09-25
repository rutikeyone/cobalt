# cobalt_annotations

Annotations for [Cobalt](https://github.com/rutikeyone/cobalt), a dependency injection framework for
Dart and Flutter.

This package holds nothing but the annotations, so neither the runtime nor the analyzer leaks into
a dependency graph that only needs the markers. Most applications depend on `cobalt` instead, which
re-exports everything here.

| Annotation | Applies to | Effect |
|---|---|---|
| `@CobaltInject` / `@cobaltInject` | class | registers the class; `lifetime`, `name`, `exposeAs`, and `lazyInit` on an async module member |
| `@cobaltSingleton` / `@cobaltTransient` | class | shorthands for the other two lifetimes |
| `@Injected` / `@injected` | `late final` field | fills the field through the generated mixin |
| `@Named` | parameter or field | selects a named registration |
| `@CobaltParam` / `@cobaltParam` | constructor parameter | the call site supplies it, not the graph |
| `@CobaltBootstrap` | class | a phase-0 step, run before the container exists |
| `@CobaltInit` | class | an async singleton, with `dependsOn`; `lazy: true` builds it on the first `getAsync` |
| `@cobaltLazyInit` | class | shorthand for `@CobaltInit(lazy: true)` |
| `@CobaltModule` / `@cobaltModule` | class | its annotated members register types you do not own |
| `@CobaltDecorates` | class | wraps what the registration of its target hands out; `name` and `order` among several |
| `@CobaltScopeRoot` | class | names the root scope; `provides` declares registrations made by hand |
| `CobaltProvided` | inside `provides` | a hand-made registration that carries a `@Named` qualifier |
| `@CobaltEnvironment` | class | optional — restricts the registration to an environment; repeat it for several |
