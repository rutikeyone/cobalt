<p align="center">
  <a href="RECIPES.md">English</a> · <a href="RECIPES.ru.md">Русский</a> · <a href="RECIPES.zh-CN.md">中文</a> · <a href="RECIPES.ko.md">한국어</a>
</p>

# 实用示例

五个常见任务，每个都配有某个示例里实现它的代码。本页的代码从那些文件复制而来，并由测试与原文件核对，所以照原样就能运行。

- [登录后的会话](#登录后的会话)
- [拥有自己作用域的界面](#拥有自己作用域的界面)
- [由作用域关闭的 bloc](#由作用域关闭的-bloc)
- [go_router 上的流程](#go_router-上的流程)
- [在测试里替换依赖](#在测试里替换依赖)

## 登录后的会话

会话持有的东西放进它自己的作用域：用户登录时创建，退出时销毁。其中构建的一切都随之关闭，从新到旧，所以没有哪个仓库需要 `reset()`。作用域说明会话里有什么：

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

登录时把它创建在应用作用域之下并启动；退出时销毁它：

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

可运行的代码：[`examples/notes_app/lib/features/session`](../examples/notes_app/lib/features/session)，以及 gallery 里的「会话作用域」条目。更多见 [GUIDE_CODEGEN.zh-CN.md](../GUIDE_CODEGEN.zh-CN.md#9-比应用先结束的作用域)。

## 拥有自己作用域的界面

继承 `CobaltScopedStatefulWidget` 的控件在挂载时创建一个作用域，离开时销毁它。界面在那里注册的东西，寿命正好和界面一样长：

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

`buildScoped` 运行在这个作用域之下，所以 `context.cobalt<NoteDraft>()` 从它读取。可运行的代码：[`examples/notes_app/lib/features/note_detail`](../examples/notes_app/lib/features/note_detail)，以及 gallery 里的「由控件持有的作用域」条目。

## 由作用域关闭的 bloc

bloc 有 `close()`，但作用域不知道要调用它。`cobalt_bloc` 的 `CobaltBloc` mixin 会告诉它：

<!-- from: packages/cobalt_bloc/test/cobalt_bloc_test.dart -->

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}
```

像注册其他类一样注册它，用 `@cobaltInject` 或 `registerLazySingleton`。交给控件树时用 `BlocProvider.value`，不要用 `BlocProvider(create:)`：后者会在卸载时关闭 bloc，而作用域仍然持有它。对于无法混入 mixin 的 bloc，在注册处写 `dispose: closeBloc` 效果相同。代码来自 [`packages/cobalt_bloc/test`](../packages/cobalt_bloc/test)。

## go_router 上的流程

结账流程跨越多个路由，拥有不属于其中任何一个的状态。`cobalt_go_router` 的 `CobaltShellRoute` 给它一个作用域，只要导航还在流程内部，作用域就一直存在。作用域：

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

拥有它的路由：

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

这个路由下的每个界面都用 `context.cobalt<OrderDraft>()` 读取，离开流程时草稿被销毁。可运行的代码：[`examples/flow_scopes`](../examples/flow_scopes)，以及 gallery 里的「导航流程」条目。

## 在测试里替换依赖

override 在拥有该注册的作用域里替换它，所以那里的每个工厂拿到的都是替换后的对象：

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

`cobaltTestScope` 和 `CobaltOverride` 分别来自 `cobalt_test` 和 `cobalt`。可运行的代码：[`examples/testing_patterns`](../examples/testing_patterns)，里面还有另一种方式，即从子作用域遮蔽，以及两种方式各自能影响到哪里。
