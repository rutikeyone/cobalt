# cobalt_bloc

Lets an [Cobalt](https://github.com/rutikeyone/cobalt) scope close the blocs it built.

```yaml
dependencies:
  cobalt_bloc: ^0.2.0
```

```dart
@cobaltInject
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);
}
```

That is the package. Everything below is why three lines are worth one.

## What goes wrong without it

A scope releases what implements `Disposable` or `AsyncDisposable`, and Dart has no structural
typing. `close()` is neither the interface the scope looks for nor even the right name, so a bloc
registered in a graph is built, used, and **never closed** — quietly, with nothing about the code
looking wrong.

`cobalt_lint` reports it as `cobalt_registration_is_never_released`, which is how you find the ones
already written. This package is how you fix them.

## Where a mixin will not reach

A bloc from another package, or one behind a base class you do not control, cannot be mixed into.
Name the function instead:

```dart
@CobaltInject(dispose: closeBloc)
class CounterCubit extends Cubit<int> { ... }

scope.registerLazySingleton<CounterCubit>(factory, dispose: closeBloc);
```

`closeBloc` takes `BlocBase<Object?>` and is still accepted where a function of the registered type
is wanted: Dart checks function parameters contravariantly, and every bloc is one of these.

Prefer the mixin where the class is yours. It keeps the knowledge on the object rather than
repeating it at every registration of it.

## With flutter_bloc

Cobalt builds the bloc; `BlocBuilder` still renders it. Resolve it where you would have created it,
and use **`BlocProvider.value`**:

```dart
BlocProvider.value(
  value: context.cobalt<CounterCubit>(),
  child: const CounterView(),
)
```

`BlocProvider(create: ...)` closes what it created when the widget unmounts. Handed a bloc the scope
owns, that closes it early — the scope still holds it, and the next resolve returns something dead.
`.value` provides without taking ownership, which is the whole difference: **the scope owns the
lifetime, the widget only reads it.**

## Why this is pure Dart

Nothing here needs widgets, and a bloc registered in a scope is a bloc whether or not Flutter is
present — so this depends on `bloc` rather than `flutter_bloc`, the same split
[`cobalt_talker`](https://pub.dev/packages/cobalt_talker) makes against `cobalt_talker_flutter`. There
is no Flutter half yet because there is nothing for one to hold: the line above is three words long
and belongs in your build method, not behind a wrapper.
