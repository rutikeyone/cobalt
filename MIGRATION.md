<p align="center">
  <a href="MIGRATION.md">English</a> · <a href="MIGRATION.ru.md">Русский</a> · <a href="MIGRATION.zh-CN.md">中文</a>
</p>

# Migrating to Cobalt

Nobody starts a Flutter app with no dependency injection and then goes shopping
for a framework. You are here because you already have `get_it`, or
`get_it` + `injectable`, and something about it stopped scaling.

This guide is in two halves: what maps onto what, and what does not map at all.
The second half is the useful one.

## The one rule that makes migration survivable

**Move from the leaves inward.** Register the things nothing depends on first,
let Cobalt and your old container coexist, and only convert the root once
everything under it is already Cobalt's.

Manual Mode exists for exactly this. The generated container and a hand-written
one are the same runtime, so a half-migrated app is a normal state, not a
broken one:

```dart
final app = await CobaltApplication.start(root: const AppScope());

// Everything not yet moved still comes from get_it. One line, deleted last.
GetIt.I.registerSingleton<Database>(app.get<Database>());
```

Resist the temptation to convert the root component first. It is the one with
the most edges, and until its dependencies are Cobalt's you gain nothing.

## get_it → Cobalt

### Registration

| get_it | Cobalt |
|---|---|
| `registerFactory<T>(() => T())` | `registerFactory<T>(const TFactory())` |
| `registerSingleton<T>(instance)` | `registerSingleton<T>(instance)` |
| `registerLazySingleton<T>(() => T())` | `registerLazySingleton<T>(const TFactory())` |
| `registerSingletonAsync<T>(() async => …)` | `registerAsyncSingleton<T>(const TFactory())` |
| `registerSingletonWithDependencies<T>(…, dependsOn: [A])` | `registerAsyncSingleton<T>(…, dependsOn: {CobaltKey(A)})` |
| `registerLazySingletonAsync<T>(() async => …)` | `registerLazyAsyncSingleton<T>(const TFactory())` |
| `registerFactoryParam<T, P, void>((p, _) => …)` | `registerParamFactory<T, P>(const TFactory())` |
| `getIt<T>()` / `getIt.get<T>()` | `scope.get<T>()` |
| `getIt<T>(instanceName: 'a')` | `scope.get<T>(name: 'a')` |
| `await getIt.getAsync<T>()` | `await scope.getAsync<T>()` |
| `getIt.isRegistered<T>()` | `scope.isRegistered<T>()` |
| `pushNewScope(...)` | `scope.push('name')` |
| `popScope()` | `await child.dispose()` |
| `reset()` | `await root.dispose()` |

The visible difference is **a factory object instead of a closure**. It buys
two things: the registration can be `const`, and the graph becomes an
inspectable value rather than captured state — which is what lets the generator
emit it and the linter read it.

### Lifecycle

`allReady()` and `isReady<T>()` have no equivalent, and do not need one.
`CobaltApplication.start` returns only when the whole async graph is up, so
there is nothing to poll and no timeout to tune:

```dart
// get_it
GetIt.I.registerSingletonAsync<Database>(() => Database.open());
await GetIt.I.allReady(timeout: const Duration(seconds: 30));

// Cobalt
final app = await CobaltApplication.start(root: const AppScope());
```

`signalReady` and the manual-signalling mode have no equivalent either. Cobalt
derives readiness from the graph rather than from you announcing it.

### Scopes are a tree, not a stack

This is the change that matters, and the one a mechanical port gets wrong.

get_it's scopes are a **flat LIFO stack**: `pushNewScope` always pushes onto
the one stack, and `get<T>()` walks it from the top down. Two independent
subtrees — say two tabs, each with its own session — cannot be expressed.

Cobalt's scopes form a **tree**. `push` creates a child of *that* scope, and
resolution walks up to the root through parents. So:

```dart
final tabA = app.push('tab:a');
final tabB = app.push('tab:b');   // sibling, not stacked on top of tabA
```

Practical consequences when porting:

- A `pushNewScope`/`popScope` pair that was really "temporary override" ports
  directly. One that relied on stack order across unrelated features probably
  hid a bug that the tree makes impossible.
- Disposal is LIFO **by creation order**, not by declaration order. If your old
  teardown depended on the order fields were declared in, it was already
  fragile.
- Whoever creates a scope disposes it. There is no ambient "current scope".

### What Cobalt does not have

Be aware of these before you commit to the move:

- **`registerFactoryParam<T, P1, P2>`** — Cobalt's `registerParamFactory<T, P>`
  takes one parameter, and a record is how several become one. Prefer the named
  form, `({int id, String title})`: it keeps the names at the call site and in
  the factory, which a positional record does not. Only the values the
  container cannot know go in it — dependencies still come from the resolver,
  so the record is usually smaller than the parameter list it replaces. In
  Code-Gen Mode you do not write any of that: mark the parameters with
  `@CobaltParam` and the generator emits the record type, the factory and the
  registration.
- **`registerFactoryAsync`** — a fresh async build on every call. Cobalt has a
  lazy async *singleton* (`registerLazyAsyncSingleton`, read with `getAsync`),
  built by the first call and kept; a per-call async factory is not there.
  Build the value in the caller, or register a lazy singleton that produces
  what each call needs.
- **`resetLazySingletons`** — dispose the scope instead. Resetting instances
  underneath live holders is the class of bug scopes exist to prevent.
- **A global instance.** There is no `GetIt.I`. A scope is passed, injected, or
  read from the widget tree with `context.cobalt<T>()`. This is deliberate: the
  global is what makes get_it graphs untestable in parallel.

## injectable → Cobalt

### Annotations

| injectable | Cobalt |
|---|---|
| `@injectable` | `@cobaltTransient` — a fresh instance per resolution |
| `@singleton` | `@cobaltSingleton` — eager, built while the container assembles |
| `@lazySingleton` | `@cobaltInject` — the default, and the one you want most of the time |
| `@Injectable(as: Foo)` | `@CobaltInject(exposeAs: Foo)` |
| `@Named('a')` | `@Named('a')` |
| `@Environment(Environment.dev)` | `@CobaltEnvironment.dev` — repeat the annotation for several |
| `@preResolve` | `@CobaltInit()` |
| `@disposeMethod` | `implements Disposable` / `AsyncDisposable` |
| `@factoryMethod` | the first public generative constructor, or an `@CobaltModule` member when it is not that one |
| `@factoryParam` | `@CobaltParam` on the constructor parameter |
| `@InjectableInit()` + `configureDependencies()` | `@CobaltScopeRoot()` + generated `$startCobalt()` |

### What changes shape

**`@module` becomes `@CobaltModule`, and stays close.** The shape carries over
almost unchanged — a class whose members provide types you do not own:

```dart
// injectable
@module
abstract class AppModule {
  @lazySingleton
  Dio get dio => Dio();
}

// Cobalt
@cobaltModule
class AppModule {
  const AppModule();

  @cobaltInject
  Dio get dio => Dio();
}
```

Three differences. The class is **concrete with a `const` constructor** rather
than abstract, because Cobalt calls the member on `const AppModule()` instead of
generating a subclass. **Abstract members are rejected**: injectable uses them
to mean "build it from its own constructor", which is what `@CobaltInject` on
the class already means, and binding to an interface is `exposeAs`. And
`Future<T>` alone marks a member async — there is no `@preResolve`.

**`dispose:` replaces `@disposeMethod` for foreign types.** A class you own
implements `Disposable`; a `Dio` cannot, so the registration says how:
`@CobaltInject(dispose: closeClient)`.

**`@Order` disappears.** injectable makes you declare ordering; Cobalt computes
it. Registrations are sorted by a compile-time topological sort in which
property-injected fields count as dependency edges, and a cycle fails the build
naming the cycle instead of recursing until the stack overflows.

**Generic classes are rejected.** `@CobaltInject class Cache<T>` is a build
error, because nothing tells the generator which instantiations to register.
Annotate a concrete subtype, or expose one:
`@CobaltInject(exposeAs: Cache<Note>)`. Generic *dependencies* work normally —
`Repository<User>` and `Repository<Order>` are separate registrations.

### What you gain

**Property injection**, which is the reason to switch if your controllers take
five to fourteen constructor arguments:

```dart
// before
class NotesCubit extends Cubit<NotesState> {
  NotesCubit({
    required this.repository,
    required this.telemetry,
    required this.session,
    required this.formatter,
    required this.config,
  }) : super(const NotesState());
  …
}

// after
@cobaltTransient
class NotesCubit extends Cubit<NotesState> with _$NotesCubit {
  NotesCubit() : super(const NotesState());

  @injected
  late final NoteStore _repository;

  @injected
  late final Telemetry _telemetry;
}
```

The mixin is generated beside the class and fills the fields immediately after
construction. Fields may be private — the part file is in the same library.
`late final` is enforced, so a second assignment throws instead of silently
replacing a dependency.

**Real disposal.** A scope owns what it created and tears it down in reverse
order of creation. Sign-out becomes `await sessionScope.dispose()`, with no
session listener anywhere and no `reset()` bolted onto domain interfaces.

## flutter_bloc and provider → Cobalt

Neither is a competitor to replace wholesale, and the two go different ways.

**`provider` is what Cobalt's `CobaltScopeProvider` already is.** If you use it only to push a
container down the tree — which is what a hand-rolled DI does — that use is gone: `CobaltAppScope`
publishes the root and `context.cobalt<T>()` reads it. If you use `ChangeNotifierProvider` to give
one widget subtree an object with a lifetime, that is `CobaltScopeWidget`, and the lifetime becomes
the scope's rather than the widget's bookkeeping.

**`flutter_bloc` is not replaced at all.** Cobalt builds the bloc; `BlocBuilder` still renders it.
Resolve it where you would have created it:

```dart
BlocProvider.value(
  value: context.cobalt<CounterCubit>(),
  child: const CounterView(),
)
```

The part that needs saying out loud is teardown. A scope releases what implements `Disposable` or
`AsyncDisposable`, and a `Cubit` closes with `Future<void> close()`, which is neither. Bridge it
once per class:

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {}
```

That mixin is [`cobalt_bloc`](https://pub.dev/packages/cobalt_bloc), which exists for this one
sentence; writing `implements AsyncDisposable` and `Future<void> dispose() => close();` by hand does
the same thing. For a bloc you cannot mix into, name the function:
`@CobaltInject(dispose: closeBloc)`. And use `BlocProvider.value` rather than
`BlocProvider(create: ...)` — the latter closes what it was handed, and the scope still owns it.

A `ChangeNotifier` needs even less — its `dispose` already matches, so `implements Disposable` is
the whole change. Skip either and the object is built, used and never closed, quietly. See the
[`cobalt_flutter` README](packages/cobalt_flutter/README.md) for the full table.

## A worked order

1. Add `cobalt` and `cobalt_annotations`; leave the old container in place.
2. Write a root `CobaltScopeBuilder` with the two or three leaf services nothing
   depends on. Start it in `main` alongside the old container.
3. Bridge: register those instances into the old container so existing call
   sites keep working.
4. Move consumers of those leaves. Each one converted removes a bridge line.
5. Repeat inward. The bridge shrinks monotonically — if it stops shrinking, the
   remaining edges are telling you something about the design.
6. When the bridge is empty, delete the old container and switch the app to
   `CobaltAppScope`.
7. Only now consider code generation: add `cobalt_generator`, replace the
   hand-written registrations with annotations one file at a time.

Step 7 is last on purpose. Generation is a convenience over a runtime you
should already trust.
