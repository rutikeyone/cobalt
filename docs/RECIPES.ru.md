<p align="center">
  <a href="RECIPES.md">English</a> · <a href="RECIPES.ru.md">Русский</a> · <a href="RECIPES.zh-CN.md">中文</a> · <a href="RECIPES.ko.md">한국어</a>
</p>

# Рецепты

Пять частых задач, у каждой код, который решает ее в одном из примеров. Код на этой странице
скопирован из этих файлов, и тест сверяет его с ними, так что он работает в том виде, как показан.

- [Сессия после входа](#сессия-после-входа)
- [Экран со своим скоупом](#экран-со-своим-скоупом)
- [Блок, который закрывает скоуп](#блок-который-закрывает-скоуп)
- [Флоу на go_router](#флоу-на-go_router)
- [Подмена зависимости в тесте](#подмена-зависимости-в-тесте)

## Сессия после входа

То, что принадлежит сессии, живет в отдельном скоупе: он создается при входе пользователя и
разбирается при выходе. Все, что в нем построено, закрывается вместе с ним, от новых к старым, так что
ни одному репозиторию не нужен `reset()`. Скоуп описывает, что лежит в сессии:

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

Вход создает его под скоупом приложения и запускает; выход его разбирает:

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

Рабочий код: [`examples/notes_app/lib/features/session`](../examples/notes_app/lib/features/session)
и запись «Сессионный скоуп» в галерее. Подробнее в
[GUIDE_CODEGEN.ru.md](../GUIDE_CODEGEN.ru.md#9-скоупы-которые-кончаются-раньше-приложения).

## Экран со своим скоупом

Виджет-наследник `CobaltScopedStatefulWidget` создает скоуп при монтировании и разбирает его, когда
уходит. То, что экран там регистрирует, живет ровно столько, сколько экран:

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

`buildScoped` работает под скоупом, поэтому `context.cobalt<NoteDraft>()` читает из него. Рабочий
код: [`examples/notes_app/lib/features/note_detail`](../examples/notes_app/lib/features/note_detail)
и запись «Скоуп, которым владеет виджет» в галерее.

## Блок, который закрывает скоуп

У блока есть `close()`, но скоуп не знает, что его надо вызвать. Миксин `CobaltBloc` из
`cobalt_bloc` ему об этом говорит:

<!-- from: packages/cobalt_bloc/test/cobalt_bloc_test.dart -->

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}
```

Регистрируйте его как любой класс, через `@cobaltInject` или `registerLazySingleton`. В дерево
виджетов отдавайте через `BlocProvider.value`, а не `BlocProvider(create:)`: второй закроет блок при
размонтировании, хотя скоуп все еще его держит. Для блока, в который миксин не подмешать, то же самое
делает `dispose: closeBloc` в регистрации. Код взят из
[`packages/cobalt_bloc/test`](../packages/cobalt_bloc/test).

## Флоу на go_router

Флоу оформления заказа занимает несколько маршрутов и владеет состоянием, которое не принадлежит ни
одному из них. `CobaltShellRoute` из `cobalt_go_router` дает ему скоуп, который живет, пока навигация
остается внутри флоу. Скоуп:

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

Маршрут, которому он принадлежит:

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

Каждый экран под этим маршрутом читает `context.cobalt<OrderDraft>()`, а выход из флоу разбирает
черновик. Рабочий код: [`examples/flow_scopes`](../examples/flow_scopes) и запись «Навигационные
флоу» в галерее.

## Подмена зависимости в тесте

Override заменяет регистрацию в том скоупе, которому она принадлежит, поэтому замену получает каждая
фабрика этого скоупа:

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

`cobaltTestScope` и `CobaltOverride` берутся из `cobalt_test` и `cobalt`. Рабочий код:
[`examples/testing_patterns`](../examples/testing_patterns), там же второй способ, затенение из
дочернего скоупа, и до чего дотягивается каждый.
