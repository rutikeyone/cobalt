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

What a session holds goes into a scope of its own, opened when the user signs in and disposed when
they sign out. Everything built in it is closed with it, newest first, so no repository needs a
`reset()`. A marker says what the session is opened with:

<!-- from: examples/notes_app/lib/features/session/session.dart -->

```dart
@CobaltChildScope()
class Session {
  const Session(this.user);

  final SessionUser user;
}
```

A class that lives in the session names it, and may inject what the session and the app register:

<!-- from: examples/notes_app/lib/features/session/data/session_activity_log.dart -->

```dart
@CobaltInject(scope: Session)
class SessionActivityLog implements Disposable {
  SessionActivityLog(this._user, this._appLog);
```

From the two the generator writes `SessionScope`: it registers the user and every class marked
`scope: Session`, and the build fails if one of them asks for something neither the session nor the
app registers. A `CobaltScopeHolder` holds it: signing in opens it under the app scope and closes
the one before, signing out closes it. The calls run one after another, so a sign-out that arrives
while a sign-in is still starting closes that session instead of finding nothing to close:

<!-- from: examples/notes_app/lib/features/session/session_manager.dart -->

```dart
Future<void> signIn(SessionUser user) async {
  await _session.open('session:${user.id}', SessionScope(user));
}

Future<void> signOut() async {
  await _session.close();
}
```

A held scope is not in the widget tree, so widgets below it read the app scope. `CobaltHeldScope`
publishes whatever the holder holds and shows something else while nobody is signed in; or let a
widget own a session that lives as long as part of the UI:

```dart
CobaltHeldScope(
  holder: session,
  absent: const SignInScreen(),
  child: const HomeScreen(),
)
```

```dart
CobaltScopeWidget(builder: SessionScope(user), child: const HomeScreen())
```

When another user signs in, the widget is rebuilt with a `SessionScope` of other values. A generated
builder compares by them, so the widget closes the old session and opens one for the new user. A
builder you write is read once: give the widget `key: ValueKey(user.id)` instead.

Running code: [`examples/notes_app/lib/features/session`](../examples/notes_app/lib/features/session)
and the *Session scope* entry in the gallery. More in
[GUIDE_CODEGEN.md](../GUIDE_CODEGEN.md#9-scopes-that-end-before-the-app-does).

## A screen with its own scope

A screen whose state should end with it gets a scope the same way. The marker holds nothing here, and
the classes of the screen name it:

<!-- from: examples/notes_app/lib/features/note_detail/ui/note_detail.dart -->

```dart
@CobaltChildScope()
class NoteDetail {}
```

<!-- from: examples/notes_app/lib/features/note_detail/ui/note_draft.dart -->

```dart
@CobaltInject(scope: NoteDetail)
class NoteDraft implements Disposable {
```

`CobaltScopeWidget` opens the generated `NoteDetailScope` when it mounts and disposes it when it
leaves, so the draft lives exactly as long as the screen:

<!-- from: examples/notes_app/lib/features/note_detail/ui/note_detail_screen.dart -->

```dart
class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key});

  @override
  Widget build(BuildContext context) => const CobaltScopeWidget(
    name: 'NoteDetailScreen',
    builder: NoteDetailScope(),
    loading: Center(child: CircularProgressIndicator()),
    child: _NoteDetailBody(),
  );
}
```

Everything below `child` reads from that scope, so `context.cobalt<NoteDraft>()` finds the draft.
Running code: [`examples/notes_app/lib/features/note_detail`](../examples/notes_app/lib/features/note_detail)
and the *Widget-owned scope* entry in the gallery.

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
it unmounts, while the scope still holds it; `cobalt_lint` reports that in the editor and rewrites
it. For a bloc you cannot mix into, `dispose: closeBloc` at
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

### With the generator

The flow above is written by hand, because `examples/flow_scopes` is about navigation and stays in
Manual Mode. With the generator, a marker says what the flow is opened with, and the classes of the
flow name it:

<!-- from: examples/notes_app/lib/features/order_flow/order_flow.dart -->

```dart
@CobaltChildScope()
class OrderFlow {
  const OrderFlow(this.orderId);

  final String orderId;
}
```

<!-- from: examples/notes_app/lib/features/order_flow/order_note.dart -->

```dart
@CobaltInject(scope: OrderFlow)
class OrderNote implements Disposable {
  OrderNote(this.orderId, this._log) {
```

The route hands the generated `OrderFlowScope` to `CobaltShellRoute`, which takes any scope
builder:

<!-- from: examples/notes_app/lib/features/order_flow/order_flow_route.dart -->

```dart
class OrderFlowRoute extends CobaltShellRoute {
  OrderFlowRoute()
    : super(
        name: 'order',
        identity: _orderId,
        scope: (state) => OrderFlowScope(_orderId(state)),
        routes: [
          GoRoute(
            path: '/orders/:orderId',
            builder: (_, _) => const OrderNoteText(),
          ),
        ],
      );

  static String _orderId(GoRouterState state) =>
      state.pathParameters['orderId']!;
}
```

Running code: [`examples/notes_app/lib/features/order_flow`](../examples/notes_app/lib/features/order_flow).

### Without cobalt_go_router

`cobalt_go_router` needs go_router 17 or later: it passes on `notifyRootObserver`, which go_router
added in 17.0.0. On an older go_router the flow is a plain `ShellRoute` whose builder wraps the shell
in `CobaltScopeWidget`. The key holds the order id, so going to another order replaces the scope, and
leaving the routes of the shell disposes it:

<!-- from: examples/flow_scopes/test/plain_shell_route_test.dart -->

```dart
final orderFlow = ShellRoute(
  builder: (context, state, child) {
    final orderId = state.pathParameters['orderId']!;
    return CobaltScopeWidget(
      key: ValueKey(orderId),
      name: 'order:$orderId',
      builder: OrderFlowScope(orderId),
      child: OrderFlowChrome(child: child),
    );
  },
  routes: [
    GoRoute(
      path: '/orders/:orderId/summary',
      builder: (_, state) =>
          OrderSummaryScreen(orderId: state.pathParameters['orderId']!),
    ),
    GoRoute(
      path: '/orders/:orderId/payment',
      builder: (_, state) =>
          OrderPaymentScreen(orderId: state.pathParameters['orderId']!),
    ),
  ],
);
```

Build the route once, with the rest of the route table, as with `CobaltShellRoute`: a new
`ShellRoute` object is a new page to go_router, and the scope would be rebuilt with it. The code is
from [`examples/flow_scopes/test/plain_shell_route_test.dart`](../examples/flow_scopes/test/plain_shell_route_test.dart), which checks entering the flow, moving inside it, switching orders and leaving.

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
