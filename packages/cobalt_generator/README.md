# cobalt_generator

Writes the [Cobalt](https://pub.dev/packages/cobalt) container for you: annotate your classes, run
`build_runner`, and a missing dependency fails the build instead of the app.

## Install

```bash
flutter pub add cobalt cobalt_flutter dev:cobalt_generator dev:build_runner
```

In a pure Dart package, `dart pub add cobalt dev:cobalt_generator dev:build_runner`. The generator
is a dev dependency: it never ships in an application.

## Quick start

**1. Annotate** each class the graph should build. Its constructor parameters are its
dependencies:

```dart
@cobaltInject
class Clock {
  Clock();

  DateTime now() => DateTime.now();
}

@cobaltInject
class Greeter {
  Greeter(this.clock);

  final Clock clock;
}
```

**2. Generate** the container:

```bash
dart run build_runner build
```

It writes `lib/cobalt.g.dart`: a factory per class, and `$CobaltRootScope`, which registers them in
dependency order. `CobaltRoot` is the same class under a name without the `$`.

**3. Start** the generated root. In a Flutter app, hand it to `CobaltAppScope` from
[`cobalt_flutter`](https://pub.dev/packages/cobalt_flutter):

```dart
builder: CobaltAppScope.builder(root: const CobaltRoot()),
```

Anywhere else, to `CobaltApplication`:

```dart
final app = await CobaltApplication.start(root: const CobaltRoot());
final greeter = app.get<Greeter>();
```

## When a dependency is missing

Take `@cobaltInject` off `Clock` and the build stops, naming the gap:

```
Greeter requires Clock, which nothing registers. Annotate the class that provides
it with @CobaltInject, add an @CobaltModule member returning it when the type is
not yours, or name it in @CobaltScopeRoot(provides: [...]) when something outside
the generated container registers it.
```

Every gap is reported in one build, so a graph is fixed in one pass.

## Learn more

| | |
|---|---|
| **Step by step, with the generator** | [GUIDE_CODEGEN.md](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_CODEGEN.md) |
| **What the generated file looks like** | [What comes out](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_CODEGEN.md#3-what-comes-out) |
| **Registering a type from another package** | [Types you did not write](https://github.com/rutikeyone/cobalt/blob/main/GUIDE_CODEGEN.md#14-types-you-did-not-write) |
| **Something threw** | [docs/TROUBLESHOOTING.md](https://github.com/rutikeyone/cobalt/blob/main/docs/TROUBLESHOOTING.md) |
| **A whole Flutter app, with a test** | [`examples/hello`](https://github.com/rutikeyone/cobalt/tree/main/examples/hello) |
| **Property injection, a decorator, a scope per screen** | [`examples/codegen_basics`](https://github.com/rutikeyone/cobalt/tree/main/examples/codegen_basics) |

## Reference

Everything below describes the generator in full.


## Builders

| Builder | Input → output | Purpose |
|---|---|---|
| `cobalt_property_injection` | `.dart` → `.cobalt.g.part` | mixins that fill `late final` fields |
| `cobalt_scan` | `.dart` → `.cobalt.json` | per-library IR, cached |
| `cobalt_container` | `$lib$` → `lib/cobalt.g.dart` | the container, bootstrap list and `$startCobalt()` |

A build step can only see one library at a time, so `cobalt_scan` writes a per-library IR and
`cobalt_container` aggregates every `.cobalt.json` into a single container.

Generated registrations are ordered by a compile-time topological sort, and property-injected
fields count as dependency edges. A dependency cycle fails the build naming the cycle instead of
emitting code that would deadlock at runtime.

## Registering types you did not write

`@CobaltInject` goes on a class, so it only reaches classes you own. A module is
the way in for everything else — a client from another package, a value the SDK
hands you, an object built by a factory function:

```dart
@cobaltModule
class NetworkModule {
  const NetworkModule();

  @cobaltInject
  Dio dio(AppConfig config) => Dio(BaseOptions(baseUrl: config.apiBase));

  @CobaltInject(dispose: closeClient)
  http.Client client() => http.Client();

  @cobaltSingleton
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
```

The annotation carries nothing. Every member configures its own registration
with the same annotations a class uses, so lifetimes, `@Named`, `exposeAs` and
`@CobaltEnvironment` all work unchanged, and each member's parameters are
resolved from the scope like constructor parameters.

The class needs a public `const` constructor taking no arguments — the emitted
factory holds `const NetworkModule()`, so it allocates nothing and carries no
state. Members must be public instance members, and every parameter must be
required — positional or named, called the way it was declared. An optional one
is refused, because every parameter is resolved from the scope and there is
nothing for a default to mean.

**`Future<T>` is the only async signal.** A member returning it registers `T`
as an async singleton built during startup; there is no `@CobaltInit` on a
member, because the return type already says it. Ordering between async members
is **worked out, not written**: the generator sees the whole package, so it
emits the `dependsOn` a hand-written registration would have stated.

**A member cannot be abstract.** "Build it from its own constructor" is what
`@CobaltInject` on the class already means, and publishing it under an interface
is what `exposeAs` means.

**`dispose` is how a type that cannot close itself gets closed.** The scope owns what it builds,
but it only recognises `Disposable` and `AsyncDisposable` — Dart has no structural typing, so a
class with a matching `dispose` or a `close()` is invisible to it. Point `dispose` at a top-level or
static function taking the registered type and the scope calls it at teardown, in the same
reverse-creation order as everything else.

It works on a **class** as well as on a module member. That is worth stating because it used not
to: the annotation declared the argument, the class parser never read it, and a class naming one
registered without it and was never closed — silently, since nothing about the code looked wrong.
Prefer implementing the interface where the class is yours to change; reach for `dispose` when it
is not, which is every `Bloc`, `Cubit` and `StreamController`.

Pairing it with a transient or a parameterized registration is a build error: the scope retains
neither, so it could never call it.

## Decorators

`@CobaltDecorates(Target)` on a class that implements `Target` and takes one `Target` in its
constructor — the instance it wraps. The class is not registered; the generator emits a
`CobaltDecorator` around it and a `scope.decorate<Target>(...)` after the registrations in
`build()`, so every `get<Target>()` hands out the wrapper. Every other constructor parameter is
resolved from the scope that owns the registration.

What the build checks:

- the target is registered in every environment where the decorator is active, or named in
  `provides:`;
- the decorator's own dependencies are complete, and none of them is a lazy async registration or
  an async transient — a decorator runs synchronously, when the instance is handed out;
- two decorators of one registration carry different `order:` values; the lower is innermost, and
  the generator does not guess from the order files were read in;
- a decorator needing something that depends on its own target fails as a cycle.

`allNames: true` wraps every registration of the target, named or not, and is emitted as
`scope.decorateAll<Target>(...)`. It cannot be combined with `name:`, needs a registration of the
type wherever it is active, and competes for `order:` with the decorators of each registration it
wraps.

`@cobaltHookAll` on a class that extends `CobaltHook<T>` is emitted as `scope.hookAll<T>(...)` in the
root scope, ahead of every registration so an eager one passes through it too. The class needs a
constructor without required parameters — nothing is built yet when hooks are added — and resolves
what it needs in `onBuilt`. Several are added by `order:`, then by class name.

An async class that resolves a decorated registration during phase 1 also waits for the async
dependencies of the decorator — the generator adds them to that class's `dependsOn`. The wait sits
on the consumer rather than the target, so an override of the target does not take it away.

## A missing registration is a build failure

Every dependency the container resolves — constructor parameters, `@injected` fields and
`@CobaltInit(dependsOn:)` — has to be registered by something, or the build fails:

```
Diagnostics requires DeviceInfo, which nothing registers. Annotate the class that
provides it with @CobaltInject, add an @CobaltModule member returning it when the
type is not yours, or name it in @CobaltScopeRoot(provides: [...]) when something
outside the generated container registers it.
```

`@CobaltInit(dependsOn:)` has a second requirement: what it waits for must itself be `@CobaltInit`.
`dependsOn` sequences phase 1, so waiting for a plain registration means waiting for something with
no async build to finish — the container would ignore that edge, and the declaration would read as
an ordering guarantee that was never in force. The build names it instead:

```
dependsOn can only wait for an async registration.
  SearchIndex waits for Logger
Annotate what it waits for with @CobaltInit, or drop the dependsOn: a registration
without an async build has nothing to finish, and the container would ignore the edge.
```

All gaps are reported together, so a graph is fixed in one pass rather than one rebuild per
missing type. A `@Named('audit')` dependency with only an unnamed registration counts as a gap:
the qualifier is part of the key.

**Registrations made by hand have to be declared.** A module covers types you do not own; this is
for registrations the generator cannot see at all — a scope builder that wraps `$CobaltRootScope`
and adds to it, or a provider from another package. Name those in the root:

```dart
@CobaltScopeRoot(name: 'app', provides: [SessionManager])
class AppScope {
  const AppScope();
}
```

Nothing is emitted for a promise; it only stops the build from failing. Use
`CobaltProvided(Logger, name: 'audit')` in the same list when the hand-written registration is
named.

**Environments are checked one at a time.** A registration restricted to `prod` is absent from
`dev`, so a dependent that is not equally restricted fails naming where the gap is (`in dev`).
Only the environments the package declares are considered — `default` joins them only when there
are none, because starting a split graph without choosing one is deliberately a runtime failure
(see the environments section of the root README). A custom `CobaltEnvironment.matches` override is
not modelled.

**Manual Mode is not covered.** A hand-written `CobaltFactory` resolves inside `create`, and nothing
static can see what it will ask for. Registrations written by hand still fail at runtime with
`CobaltNotRegisteredError`, exactly as before.

## Generic types

`Repository<User>` and `Repository<Order>` are two separate registrations, as dependencies and as
`exposeAs` targets alike. The identity of a registration includes its type arguments, matching the
runtime, where `CobaltKey` is built from `Type`.

A generic class lists the instantiations it registers, one registration each:

```dart
@CobaltInject(instantiations: [Cache<Note>, Cache<User>])
class Cache<T> {
  Cache(this.store);
  final Store<T> store;
}
```

Each instantiation gets its own factory, named after its type arguments (`_CacheOfNoteFactory`,
`_CacheOfUserFactory`; `Pair<String, int>` becomes `_PairOfStringAndIntFactory`), and its
constructor resolves its own `Store<Note>` or `Store<User>`. A generic class without
`instantiations` is a build error. Every entry spells out each type argument (a raw `Cache` reads as
`Cache<dynamic>`), and `exposeAs` is written without them: `exposeAs: Store` registers each
instantiation under its own `Store<Note>`. `@injected` fields work
too: the class mixes in `_$Cache<T>`, one mixin for every instantiation, and each reads the field
under its own type arguments, so a missing `Store<User>` fails the build for `Cache<User>` alone.

Nullability of the outer type is not part of that identity: a `Foo?` dependency reads the `Foo`
registration. A type argument keeps its `?`, so `Cache<Note?>` and `Cache<Note>` are two
registrations. What an outer `?` does change is whether the dependency is required. A nullable
parameter or `@injected` field is emitted as `resolver.getOrNull<Foo>()` and is skipped by the
completeness check, so nothing registering `Foo` injects null rather than failing the build. It stays
an ordering edge when `Foo` *is* registered, and `@CobaltInit(dependsOn:)` is never optional: it
declares order, not injection.

A module member may not return a nullable type. A nullable type marks a dependency optional; it
cannot describe a registration, because `CobaltKey` has no way to represent `Foo?`.

## Two classes with the same name

A generated factory is named after what declares the registration — `_ClockFactory` for `Clock`,
`_NetworkModuleDioFactory` for a module member — which handles two modules both providing a `Dio`.

Two libraries in one package declaring their own `Clock` is different: the build accepts both,
because a registration key is `import#name` and those are two distinct keys. Emitting
`_ClockFactory` twice would produce a file that does not compile, and the error would name the
generated symbol rather than either class you wrote.

So a base name more than one declaration claims gets a suffix on **every** claimant, derived from
the library it came from: `_ClockFactory$329` and `_ClockFactory$700`. Two properties follow, and
both are on purpose — a name nobody contests is left exactly as it was, so adding a second `Clock`
never renames anything else in the file; and the suffix is a function of the library alone, so it
does not depend on visit order and does not move between builds.

## Property injection covers `@CobaltInit` too

The `_$ClassName` mixin is written for every class the container registers, which includes one
annotated with `@CobaltInit` alone. That used to be `@CobaltInject` only, and the mismatch was silent
in the worst way: the container registered the class and awaited its `init()`, the mixin was never
written, the `@injected` fields stayed unassigned, and the first read threw a
`LateInitializationError` — while the lint told you to mix in something nothing would generate.
Both halves now read the declaration the same way.

An `@CobaltDecorates` class gets the mixin too when it has `@injected` fields. The generated
decorator constructs it and calls `onInject` on it straight away, with the resolver of the scope that
owns the registration — the scope itself never calls `onInject` on what a decorator returns, since
that may be the very instance it was handed.

## Async transients

`@cobaltTransient` on an `@CobaltInit` class — or on a module member returning a `Future` — makes an
async transient: the factory implements `CobaltAsyncFactory`, constructs, awaits `init()`, awaits any
lazy dependency through `getAsync`, and is registered with `registerAsyncFactory`. Every `getAsync`
builds a new one and the scope keeps none. Only a class whose own factory is awaited — lazy, async
parameterized or another async transient — may inject it; a `dependsOn` naming it, `lazy: true`,
`dependsOn` or a `dispose:` on it are build errors.

## Values the call site supplies

Most of a constructor comes from the graph. `@CobaltParam` marks what does not — a record id, a
route argument, a flag chosen on the screen that opened this one:

```dart
@cobaltInject
class NoteEditor {
  NoteEditor(this._notes, {@cobaltParam required this.id, @cobaltParam this.draft = false});

  final NoteRepository _notes;
  final int id;
  final bool draft;
}
```

The class becomes a parameterized registration, and the generator writes the argument type beside
the container as a **named record** built from the marked parameters:

```dart
typedef $NoteEditorArgs = ({int id, bool draft});

final class _NoteEditorFactory implements CobaltParamFactory<NoteEditor, $NoteEditorArgs> {
  const _NoteEditorFactory();
  @override
  NoteEditor create(CobaltResolver resolver, $NoteEditorArgs args) =>
      NoteEditor(resolver.get<NoteRepository>(), id: args.id, draft: args.draft);
}
```

```dart
context.cobaltWithParam<NoteEditor, $NoteEditorArgs>((id: 7, draft: true));
```

A record even for a single value, and a named one: adding a second argument then changes what the
call site passes rather than the name of the type, and the call keeps reading like the constructor
it stands for. The typedef lives in the container rather than beside the class, so annotating a
parameter does not also require a `part` directive.

A marked parameter is not a dependency. Nothing registers an `int`, so it is skipped by the
completeness check and is no edge in the ordering — while everything beside it is checked and
ordered exactly as before.

Nullability is kept: `@cobaltParam String? title` becomes a `({String? title})` field, so a
constructor willing to take null still can. A **default** is not, and an optional marked parameter
is refused rather than silently ignored — a record carries no defaults, so `@cobaltParam this.draft =
false` would leave the caller obliged to pass it anyway. Make it required, or make it nullable.

On an `@CobaltInit` class the factory is async: it implements `CobaltAsyncParamFactory`, awaits
`init()` after construction, awaits any lazy dependency through `getAsync`, and is registered with
`registerAsyncParamFactory` — read with `getAsyncWithParam`. It is built per call, never in phase 1,
so nothing may wait for it in `dependsOn` and it takes no derived `dependsOn` of its own.

Four combinations are refused, each naming the fix: `lifetime: singleton`, because a singleton is
built while the container is assembled, when no call site has supplied anything; `@CobaltInit(lazy:
true)`, because a lazy registration is one shared instance; `dependsOn` on such a class, because it
is not built by `init()`; and a module member, because a module registers types you did not write
while a call-site value belongs to a class you did.

## Constructors with named parameters

A constructor is called the way it was declared — positional arguments positionally, named ones by
name, mixed in one call where a class mixes them, and the same for a module member. This is worth
stating because it used not to be true: every argument went in positionally, which produced a file
that did not compile, and no injectable class in this repository's own examples happened to use a
named parameter, so nothing noticed until a production graph was read. Module members were refused
outright for the same reason, which stopped being a reason once the emitter could do it.
