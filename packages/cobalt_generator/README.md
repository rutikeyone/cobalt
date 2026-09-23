# cobalt_generator

Code generator for [Cobalt](https://github.com/rutikeyone/cobalt). Add it as a `dev_dependency` — it
never ships in an application.

```yaml
dev_dependencies:
  cobalt_generator: ^0.2.0
  build_runner: ^2.16.0
```

```
dart run build_runner build
```

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

`Repository<User>` and `Repository<Order>` are two separate registrations — as dependencies and as
`exposeAs` targets alike. The identity of a registration includes its type arguments, matching the
runtime, where `CobaltKey` is built from `Type`.

The injectable class itself may not be generic. `@CobaltInject class Cache<T>` is rejected at build
time, because nothing says which instantiations to register. Annotate a concrete subtype, or expose
one with `@CobaltInject(exposeAs: Cache<Note>)`.

Nullability is not part of that identity: a `Foo?` dependency reads the `Foo` registration. What it
does change is whether the dependency is required. A nullable parameter or `@injected` field is
emitted as `resolver.getOrNull<Foo>()` and is skipped by the completeness check, so nothing
registering `Foo` injects null rather than failing the build. It stays an ordering edge when `Foo`
*is* registered, and `@CobaltInit(dependsOn:)` is never optional — it declares order, not injection.

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

Three combinations are refused, each naming the fix: `@CobaltInit`, because there is no asynchronous
parameterized factory; `lifetime: singleton`, because a singleton is built while the container is
assembled, when no call site has supplied anything; and a module member, because a module registers
types you did not write while a call-site value belongs to a class you did.

## Constructors with named parameters

A constructor is called the way it was declared — positional arguments positionally, named ones by
name, mixed in one call where a class mixes them, and the same for a module member. This is worth
stating because it used not to be true: every argument went in positionally, which produced a file
that did not compile, and no injectable class in this repository's own examples happened to use a
named parameter, so nothing noticed until a production graph was read. Module members were refused
outright for the same reason, which stopped being a reason once the emitter could do it.
