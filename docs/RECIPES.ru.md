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

То, что принадлежит сессии, живет в отдельном скоупе: он открывается при входе пользователя и
разбирается при выходе. Все, что в нем построено, закрывается вместе с ним, от новых к старым, так что
ни одному репозиторию не нужен `reset()`. Маркер говорит, с чем сессия открывается:

<!-- from: examples/notes_app/lib/features/session/session.dart -->

```dart
@CobaltChildScope()
class Session {
  const Session(this.user);

  final SessionUser user;
}
```

Класс, который живет в сессии, называет ее и может внедрять то, что регистрируют сессия и приложение:

<!-- from: examples/notes_app/lib/features/session/data/session_activity_log.dart -->

```dart
@CobaltInject(scope: Session)
class SessionActivityLog implements Disposable {
  SessionActivityLog(this._user, this._appLog);
```

Из этих двух генератор пишет `SessionScope`: он регистрирует пользователя и каждый класс с
`scope: Session`, а сборка падает, если кто-то из них просит то, чего не регистрируют ни сессия, ни
приложение. Вход открывает его под скоупом приложения, выход разбирает:

<!-- from: examples/notes_app/lib/features/session/session_manager.dart -->

```dart
Future<void> signIn(SessionUser user) async {
  await signOut();
  _session = await _appScope.open('session:${user.id}', SessionScope(user));
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

Скоупа из `open` нет в дереве виджетов, поэтому виджеты ниже читают скоуп приложения. Покажите им
сессию или отдайте ее виджету, если она живет столько же, сколько часть интерфейса:

```dart
CobaltScopeProvider(scope: session, child: const HomeScreen())
```

```dart
CobaltScopeWidget(builder: SessionScope(user), child: const HomeScreen())
```

Рабочий код: [`examples/notes_app/lib/features/session`](../examples/notes_app/lib/features/session)
и запись «Сессионный скоуп» в галерее. Подробнее в
[GUIDE_CODEGEN.ru.md](../GUIDE_CODEGEN.ru.md#9-скоупы-которые-кончаются-раньше-приложения).

## Экран со своим скоупом

Экран, чье состояние должно закончиться вместе с ним, получает скоуп так же. Маркер здесь ничего не
хранит, а классы экрана называют его:

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

`CobaltScopeWidget` открывает сгенерированный `NoteDetailScope` при монтировании и разбирает, когда
уходит, поэтому черновик живет ровно столько, сколько экран:

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

Все, что ниже `child`, читает из этого скоупа, поэтому `context.cobalt<NoteDraft>()` находит
черновик. Рабочий код: [`examples/notes_app/lib/features/note_detail`](../examples/notes_app/lib/features/note_detail)
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
размонтировании, хотя скоуп все еще его держит; `cobalt_lint` показывает это в редакторе и
переписывает вызов. Для блока, в который миксин не подмешать, то же самое
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

### С генератором

Флоу выше написан руками, потому что `examples/flow_scopes` посвящен навигации и остается в ручном
режиме. С генератором маркер говорит, с чем открывается флоу, а классы флоу называют его:

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

Маршрут отдает сгенерированный `OrderFlowScope` в `CobaltShellRoute`, который принимает любой
builder скоупа:

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

Рабочий код: [`examples/notes_app/lib/features/order_flow`](../examples/notes_app/lib/features/order_flow).

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
