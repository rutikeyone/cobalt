<p align="center">
  <a href="RECIPES.md">English</a> · <a href="RECIPES.ru.md">Русский</a> · <a href="RECIPES.zh-CN.md">中文</a> · <a href="RECIPES.ko.md">한국어</a>
</p>

# 레시피

자주 하는 작업 다섯 가지와, 예제 중 하나에서 그 작업을 하는 코드입니다. 이 페이지의 코드는 그 파일들에서
복사한 것이며 테스트가 원본과 대조하므로, 보이는 그대로 동작합니다.

- [로그인한 세션](#로그인한-세션)
- [자기 스코프를 가진 화면](#자기-스코프를-가진-화면)
- [스코프가 닫는 bloc](#스코프가-닫는-bloc)
- [go_router 위의 플로우](#go_router-위의-플로우)
- [테스트에서 의존성 바꿔 끼우기](#테스트에서-의존성-바꿔-끼우기)

## 로그인한 세션

세션이 가진 것은 별도의 스코프에 넣습니다. 사용자가 로그인할 때 만들고 로그아웃할 때 해제합니다. 그 안에서
만든 모든 것이 최신 것부터 함께 닫히므로, 어떤 저장소에도 `reset()`이 필요 없습니다. 스코프는 세션에 무엇이
있는지 말합니다:

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

로그인은 앱 스코프 아래에 스코프를 만들고 시작하며, 로그아웃은 그것을 해제합니다:

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

실행되는 코드: [`examples/notes_app/lib/features/session`](../examples/notes_app/lib/features/session),
그리고 갤러리의 「세션 스코프」 항목. 자세한 내용은
[GUIDE_CODEGEN.ko.md](../GUIDE_CODEGEN.ko.md#9-앱보다-먼저-끝나는-스코프)에 있습니다.

## 자기 스코프를 가진 화면

`CobaltScopedStatefulWidget`을 상속한 위젯은 마운트될 때 스코프를 만들고 떠날 때 해제합니다. 화면이 거기에
등록한 것은 정확히 화면이 사는 동안만 삽니다:

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

`buildScoped`는 그 스코프 아래에서 실행되므로 `context.cobalt<NoteDraft>()`가 거기서 읽습니다. 실행되는
코드: [`examples/notes_app/lib/features/note_detail`](../examples/notes_app/lib/features/note_detail),
그리고 갤러리의 「위젯 소유 스코프」 항목.

## 스코프가 닫는 bloc

bloc에는 `close()`가 있지만 스코프는 그것을 불러야 하는지 모릅니다. `cobalt_bloc`의 `CobaltBloc` 믹스인이
알려 줍니다:

<!-- from: packages/cobalt_bloc/test/cobalt_bloc_test.dart -->

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);

  void increment() => emit(state + 1);
}
```

다른 클래스처럼 `@cobaltInject`나 `registerLazySingleton`으로 등록합니다. 위젯 트리에는
`BlocProvider.value`로 넘기고 `BlocProvider(create:)`는 쓰지 마십시오. 후자는 언마운트될 때 bloc을 닫지만
스코프는 여전히 그것을 들고 있습니다. 믹스인을 섞을 수 없는 bloc에는 등록에서 `dispose: closeBloc`가 같은
일을 합니다. 코드는 [`packages/cobalt_bloc/test`](../packages/cobalt_bloc/test)에서 가져왔습니다.

## go_router 위의 플로우

결제 플로우는 여러 라우트에 걸쳐 있고, 그중 어느 것도 혼자 갖지 않는 상태를 가집니다. `cobalt_go_router`의
`CobaltShellRoute`는 내비게이션이 플로우 안에 머무는 동안 사는 스코프를 줍니다. 스코프:

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

그것을 가진 라우트:

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

라우트 아래의 모든 화면은 `context.cobalt<OrderDraft>()`로 읽고, 플로우를 떠나면 초안이 해제됩니다.
실행되는 코드: [`examples/flow_scopes`](../examples/flow_scopes), 그리고 갤러리의 「내비게이션 플로우」 항목.

## 테스트에서 의존성 바꿔 끼우기

override는 그 등록을 가진 스코프에서 등록을 바꾸므로, 그 스코프의 모든 팩토리가 바뀐 것을 받습니다:

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

`cobaltTestScope`와 `CobaltOverride`는 각각 `cobalt_test`와 `cobalt`에서 옵니다. 실행되는 코드:
[`examples/testing_patterns`](../examples/testing_patterns). 다른 방법인 자식 스코프에서 가리기와, 각
방법이 어디까지 닿는지도 함께 있습니다.
