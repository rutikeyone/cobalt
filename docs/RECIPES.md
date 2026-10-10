<p align="center">
  <a href="RECIPES.md">English</a> · <a href="RECIPES.ru.md">Русский</a> · <a href="RECIPES.zh-CN.md">中文</a> · <a href="RECIPES.ko.md">한국어</a>
</p>

# Recipes

Five common tasks, each with the code that does it in one of the examples. The code on this page is
copied from those files and a test checks it against them, so it runs as shown.

- [A signed-in session](#a-signed-in-session)
- [A screen with its own scope](#a-screen-with-its-own-scope)
- [A bloc the scope closes](#a-bloc-the-scope-closes)
- [A flow on go_router](#a-flow-on-go_router)
- [Swapping a dependency in a test](#swapping-a-dependency-in-a-test)

## A signed-in session

What a session holds goes into a scope of its own, pushed when the user signs in and disposed when
they sign out. Everything built in it is closed with it, newest first, so no repository needs a
`reset()`. The scope says what a session holds:

<!-- from: examples/notes_app/lib/features/session/session_scope.dart -->

```dart
class SessionScope implements CobaltScopeBuilder {
  const SessionScope(this.user);

  final SessionUser user;

  @override
  void build(CobaltScope scope) {
    scope
      ..registerSingleton<SessionUser>(user)
      ..registerLazySingleton<SessionActivityLog>(
        const SessionActivityLogFactory(),
      );
  }
}
```

Signing in pushes it under the app scope and starts it; signing out disposes it:

<!-- from: examples/notes_app/lib/features/session/session_manager.dart -->

```dart
Future<void> signIn(SessionUser user) async {
  await signOut();
  final scope = _appScope.push('session:${user.id}');
  SessionScope(user).build(scope);
  await scope.init();
  _session = scope;
  notifyListeners();
}

Future<void> signOut() async {
  final scope = _session;
  if (scope == null) return;
  _session = null;
  await scope.dispose();
  notifyListeners();
}
```

Running code: [`examples/notes_app/lib/features/session`](../examples/notes_app/lib/features/session)
and the *Session scope* entry in the gallery. More in
[GUIDE_CODEGEN.md](../GUIDE_CODEGEN.md#9-scopes-that-end-before-the-app-does).

## A screen with its own scope

A widget that extends `CobaltScopedStatefulWidget` pushes a scope when it mounts and disposes it when
it leaves. What the screen registers there lives exactly as long as the screen:

<!-- from: examples/notes_app/lib/features/note_detail/ui/note_detail_screen.dart -->

```dart
class NoteDetailScreen extends CobaltScopedStatefulWidget {
  const NoteDetailScreen({super.key});

  @override
  Widget get loading => const Center(child: CircularProgressIndicator());

  @override
  void registerScope(CobaltScope scope) {
    scope
      ..registerLazySingleton<NoteDraft>(const NoteDraftFactory())
      ..registerParamFactory<NoteTitleCard, String>(
        const NoteTitleCardFactory(),
      );
  }

  @override
  CobaltScopedState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}
```

`buildScoped` runs below the scope, so `context.cobalt<NoteDraft>()` reads from it. Running code:
[`examples/notes_app/lib/features/note_detail`](../examples/notes_app/lib/features/note_detail) and
the *Widget-owned scope* entry in the gallery.

## A bloc the scope closes

A bloc has `close()`, which the scope does not know to call. The `CobaltBloc` mixin from
`cobalt_bloc` tells it:

<!-- from: packages/cobalt_bloc/test/cobalt_bloc_test.dart -->

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}
```

Register it like any other class, with `@cobaltInject` or `registerLazySingleton`. Hand it to the
widget tree with `BlocProvider.value`, never `BlocProvider(create:)`: the latter closes the bloc when
it unmounts, while the scope still holds it. For a bloc you cannot mix into, `dispose: closeBloc` at
the registration does the same. The code is from
[`packages/cobalt_bloc/test`](../packages/cobalt_bloc/test).

## A flow on go_router

A checkout flow spans several routes and owns state that none of them owns alone. `CobaltShellRoute`
from `cobalt_go_router` gives it a scope that lives while navigation stays inside the flow. The scope:

<!-- from: examples/flow_scopes/lib/features/orders/order_flow_scope.dart -->

```dart
class OrderFlowScope implements CobaltScopeBuilder {
  const OrderFlowScope(this.orderId);

  final String orderId;

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<OrderDraft>(OrderDraftFactory(orderId));
}
```

The route that owns it:

<!-- from: examples/flow_scopes/lib/features/orders/order_flow_route.dart -->

```dart
class OrderFlowRoute extends CobaltShellRoute {
  OrderFlowRoute()
    : super(
        name: 'order',
        identity: _orderId,
        scope: (state) => OrderFlowScope(_orderId(state)),
        shell: (_, _, child) => OrderFlowChrome(child: child),
        routes: [
          GoRoute(
            path: '/orders/:orderId/summary',
            builder: (_, state) => OrderSummaryScreen(orderId: _orderId(state)),
          ),
          GoRoute(
            path: '/orders/:orderId/payment',
            builder: (_, state) => OrderPaymentScreen(orderId: _orderId(state)),
          ),
        ],
      );

  static String _orderId(GoRouterState state) =>
      state.pathParameters['orderId']!;
}
```

Every screen under the route reads `context.cobalt<OrderDraft>()`, and leaving the flow disposes the
draft. Running code: [`examples/flow_scopes`](../examples/flow_scopes) and the *Navigation flows*
entry in the gallery.

## Swapping a dependency in a test

An override replaces a registration in the scope that owns it, so every factory there gets the
replacement:

<!-- from: examples/testing_patterns/test/overriding_test.dart -->

```dart
test('reaches the consumer registered next to it', () async {
  final scope = await cobaltTestScope(
    root: const AppScope(),
    overrides: [
      const CobaltOverride<GreetingStore>.value(
        InMemoryGreetingStore('Hello'),
      ),
      CobaltOverride<Clock>.value(FixedClock(DateTime.utc(2026, 8, 23, 9))),
    ],
  );

  expect(
    await scope.get<Greeter>().greet('Ada'),
    'Hello, Ada — it is 9:00',
    reason:
        'Greeter is registered in the root and resolves from the root, '
        'which is where the override lives',
  );
});
```

`cobaltTestScope` and `CobaltOverride` come from `cobalt_test` and `cobalt`. Running code:
[`examples/testing_patterns`](../examples/testing_patterns), together with the other way, shadowing
from a child scope, and what each one reaches.
