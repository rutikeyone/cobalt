<p align="center">
  <a href="TROUBLESHOOTING.md">English</a> · <a href="TROUBLESHOOTING.ru.md">Русский</a> · <a href="TROUBLESHOOTING.zh-CN.md">中文</a> · <a href="TROUBLESHOOTING.ko.md">한국어</a>
</p>

# Troubleshooting

Every error Cobalt throws at runtime ends with a link to its entry on this page. Each entry says when
the error happens and what to do about it.

- [Reading from the graph](#reading-from-the-graph)
- [Registering](#registering)
- [Starting and stopping](#starting-and-stopping)
- [In Flutter](#in-flutter)
- [When `build_runner` fails](#when-build_runner-fails)
- [The first build](#the-first-build)

## Reading from the graph

### CobaltNotRegisteredError

```
Config is not registered in scope "app" or its ancestors. Resolving: Api -> Repository -> Config.
Nothing in this scope tree registers Config. Register it, or if it is a @cobaltInject class, run
build_runner again.
```

Something asked for a type that no scope between here and the root registers.

- With the generator: annotate the class with `@cobaltInject` and run `dart run build_runner build`
  again. If the type is registered by hand, outside the generated container, name it in
  `@CobaltScopeRoot(provides: [...])`.
- By hand: register it in the scope's `build()`, or in a scope above it.
- `Resolving:` shows who asked, first to last. Start looking at the first name.
- After the trail comes a hint. If scopes below or beside this one register the key, the message
  names up to three of them: resolution walks up, never down, so move the registration up or resolve
  from that scope. If the type is registered under other names, it lists those keys, as in
  `Api, Api(fake)`: check the `name:`. If neither applies, it says nothing in the scope tree
  registers the key: see the first two points. The error carries the same facts as
  `registeredElsewhere` and `sameType`.
- If the message says the scope is still being built: an eager `registerSingleton` resolved its
  dependencies before they were registered further down `build()`. Move it below them, or make it
  lazy.
- A scope only sees itself and the scopes above it. A type registered in a session or screen scope
  is invisible from the root.

### CobaltNotReadyError

An async registration — `registerAsyncSingleton`, or an `@CobaltInit` class — was read before
`init()` finished building it.

- Wait for startup: `await CobaltApplication.start(...)` or `await $startCobalt()`. In Flutter,
  `CobaltAppScope` shows `loading` until the graph is ready, so read inside the app, not before
  `runApp`.
- For a scope you pushed yourself, `await child.init()` before reading from it.

### CobaltLazyAsyncError

A lazy async registration — `registerLazyAsyncSingleton`, or a lazy `@CobaltInit` class — was read
with `get` before anything built it.

- Use `await scope.getAsync<T>()`. The first call builds it, later calls get the same instance. In a
  widget, `CobaltAsyncBuilder` does the waiting.
- If it should be ready by the time a screen opens, start it early with `warmUp`.

### CobaltAsyncTransientError

`get` on an async transient — `registerAsyncFactory`, or `@cobaltTransient` on an `@CobaltInit`
class. It is built anew on every call, so every call has to be awaited.

- Use `await scope.getAsync<T>()`, or `getAllAsync` for a list. The lint rule
  `cobalt_async_transient_read_synchronously` points at it in the editor.

### CobaltParamRequiredError

The registration takes a value from the call site — `registerParamFactory`, or a class with
`@CobaltParam` — and was read without one.

- Use `scope.getWithParam<T, P>(value)`, or `getAsyncWithParam` when it is built asynchronously. In
  a widget, `context.cobaltWithParam<T, P>(value)`.

### CobaltNotParameterizedError

The opposite: `getWithParam` on a registration that takes no parameter.

- Use `get<T>()`.

### CobaltAsyncParamError

`getWithParam` on a registration that is built asynchronously from its parameter
(`registerAsyncParamFactory`).

- Use `await scope.getAsyncWithParam<T, P>(value)`.

### CobaltParamTypeError

The value passed to `getWithParam` is not the type the registration takes. Usually a record whose
fields have other names or come in another order.

- Pass exactly the declared type. With the generator, build the generated `$<Class>Args` record.

### CobaltCycleError

```
Dependency cycle detected: Session -> Api -> Session
```

The registrations in the list need each other, so none of them can be built first.

- Break the cycle: move what both sides need into a third class, or have one side resolve the other
  when it is used rather than in its constructor.
- With the generator, the build fails on a cycle, and the lint rule `cobalt_dependency_cycle` shows
  it in the editor.

## Registering

### CobaltDuplicateRegistrationError

The same type, with the same name, is registered twice in one scope.

- Remove one of them.
- To keep several implementations of one type, give each a name — `name: 'audit'` when registering,
  `get<Logger>(name: 'audit')` when reading — and read all of them with `getAll<T>()`.
- To replace a registration in a test or a flavour, use an override, not a second registration.

### CobaltScopeStateError

The scope is in the wrong state for the call. The message says which state, and what was asked:

- **An async registration after `init()` started.** `init()` takes the async registrations it finds
  when it starts, and runs once. Register them before `init()`. To add one later, push a child
  scope, register it there and `await child.init()`.
- **A scope used after `dispose()`**, or while it is being disposed. Something kept a reference to an
  old scope — often a session that was signed out. Read from the current scope instead.

### CobaltDependsOnError

`dependsOn` names something `init()` does not build: a type nothing registers, a plain registration,
a lazy one or an async factory. `dependsOn` only orders async singletons during `init()`, so there is
nothing to wait for.

- If nothing registers it, register it — the same fix as
  [CobaltNotRegisteredError](#cobaltnotregisterederror).
- Otherwise remove it from `dependsOn`. A plain dependency is resolved when it is needed, a lazy one
  by its first `getAsync`, an async factory on every `getAsync`.

### CobaltOverrideError

An override replaced nothing.

- **No type argument.** `CobaltOverride.value(FakeClock())` replaces `FakeClock` — or, inside a list,
  `Object`. Name the registered type: `CobaltOverride<Clock>.value(FakeClock())`. The lint rule
  `cobalt_override_needs_type_argument` catches it.
- **Wrong scope.** The type is registered in another scope, and the message names it. Put the
  override there, so the factories that use the type see it too.

### CobaltDecoratorError

A decorator was added too late, or wraps nothing.

- **Too late:** the instance was already handed out, and whoever holds it would keep the undecorated
  one. Add decorators in the same `build()` as the registration, before anything resolves it.
- **Wraps nothing:** this scope does not register the key. If another scope does, the message names
  it — decorate there.

### CobaltHookError

`hookAll` was called after the scope, or a scope below it, had already built instances. Those would
never pass through the hook.

- Add hooks first, where the scope is composed, before any `get` or eager registration. The lint
  rule `cobalt_hook_added_too_late` catches it in one block.

## Starting and stopping

### CobaltBootstrapError

A bootstrap step — `@CobaltBootstrap` or a `CobaltBootstrapStep` — threw. The message names the step
and carries the original error; `cause` and `causeStackTrace` hold them.

- Fix the original error. In Flutter, `CobaltAppScope` shows its `errorBuilder` with a retry button.

### CobaltInitTimeoutError

Startup ran past `init(timeout:)` or `initTimeout:`. The message lists everything not built yet.

- Find out why those are slow. A network call with no timeout of its own is the usual reason.
- Something the first screen does not need can leave startup: make it lazy
  (`registerLazyAsyncSingleton`) and build it on first use.
- Or raise the timeout.

### CobaltWarmUpError

`warmUp` could not build some registrations. The message lists each with its error. The rest were
built, and the next `getAsync` of a failed one tries again.

- Fix the errors listed. They are the same ones `getAsync` would have thrown.

### CobaltDisposeError

The scope is disposed, but some objects did not close cleanly: a `dispose()` threw, or ran past the
deadline. The message lists every failure; `hasTimeout` tells timeouts from errors.

- Fix the `dispose()` that threw. Everything else was still closed.
- For a timeout, make the slow `dispose()` faster, or give teardown more time:
  `scope.dispose(timeout: ...)`. The default is 30 seconds for the whole tree.

## In Flutter

### CobaltNoScopeError

`context.cobalt<T>()` found no scope above the widget.

- Put `CobaltAppScope` into `MaterialApp.builder`, as in the README's Quick start, or wrap the
  subtree in `CobaltScopeWidget`.
- A route opened with `Navigator.push` is built by the navigator, above the screen that opened it,
  so it cannot see a scope that screen owns. Pass the scope to the new screen, or place the scope
  above the navigator.

### CobaltNoAppScopeError

`CobaltAppScope.of(context)` — used for `restart()` — found no `CobaltAppScope` above the widget.

- Start the app with `CobaltAppScope` or `CobaltAppScope.builder`. `CobaltScopeProvider` only
  publishes a scope somebody else owns, so it cannot restart it.

## When `build_runner` fails

The generator stops the build with a message that says what to change. The usual ones:

- **A dependency nothing registers.** The same fix as
  [CobaltNotRegisteredError](#cobaltnotregisterederror): annotate the class, or name it in
  `@CobaltScopeRoot(provides: [...])`. The message lists every gap at once.
- **Two `@CobaltScopeRoot` classes in one package.** A package has one generated root. Keep one.
- **A dependency cycle.** See [CobaltCycleError](#cobaltcycleerror).
- **An abstract class with `@CobaltInject`.** The generator cannot build it. Annotate a concrete
  class and expose it under the interface: `@CobaltInject(exposeAs: ApiClient)`.
- **A generic class with `@CobaltInject`.** The message says the class declares type parameters, so
  there is no single instantiation to register. Name the ones it registers, every type argument
  spelled out: `@CobaltInject(instantiations: [Cache<Note>, Cache<User>])`. A raw `Cache` in the list
  reads as `Cache<dynamic>` and is rejected, and so are `exposeAs` beside `instantiations` and an
  `@injected` field on a generic class; take that field in the constructor.

[GUIDE_CODEGEN.md](../GUIDE_CODEGEN.md#5-the-graph-has-to-be-complete) explains how the check works,
and the [lint plugin](../GUIDE_CODEGEN.md#16-the-lint-plugin) shows most of these in the editor before
you run the build.

## The first build

What a new app shows on the way through the [Quick start](../README.md#quick-start):

- **`Target of URI hasn't been generated: 'cobalt.g.dart'`, and `$CobaltRootScope` is not a class.**
  The generator has not run yet. Run `dart run build_runner build`, and again after you change an
  annotation; `dart run build_runner watch` keeps the file current while you work.
- **`The name 'MyApp' isn't a class` in `test/widget_test.dart`.** That test came with
  `flutter create` and checks the counter app you replaced. Delete it;
  [`examples/hello/test`](../examples/hello/test) has a test for the new app.
- **`The imported package 'cobalt' isn't a dependency` in `lib/cobalt.g.dart`.** The generated code
  imports the runtime directly, so the app has to depend on it: `flutter pub add cobalt`.
