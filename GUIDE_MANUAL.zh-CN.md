<p align="center">
  <a href="GUIDE_MANUAL.md">English</a> · <a href="GUIDE_MANUAL.ru.md">Русский</a> · <a href="GUIDE_MANUAL.zh-CN.md">中文</a>
</p>

> 本文档译自 [GUIDE_MANUAL.md](GUIDE_MANUAL.md)。英文版为准：若有出入，以英文为准。

# Manual Mode（手写模式）

不带代码生成的 Cobalt：没有注解，没有 `build_runner`，什么都不生成，也没有什么要提交。
注册由你来写，而运行时就是生成器所面向的那一套。

这是完整的框架，不是它的删减版。生成器产出的一切，都是用本文所描述的东西表达的——
这是本项目一直坚持的不变量：一旦生成需要 Manual Mode 无法表达的东西，
那就是两个共用一个名字的框架了。

在这些情况下选择本模式：你正在逐步迁移一个已有的容器；图小到不值得引入一个构建步骤；
或者你所在的包根本加不了构建步骤。当你希望图在构建期而不是运行期被检查时，
去读 [GUIDE_CODEGEN.zh-CN.md](GUIDE_CODEGEN.zh-CN.md)——两种模式能组合在同一张图里，
所以这不是一个会把你锁死的决定。

---

## 目录

1. [安装](#1-安装)
2. [你的第一张图](#2-你的第一张图)
3. [注册与读取](#3-注册与读取)
4. [启动 Flutter 应用](#4-启动-flutter-应用)
5. [在 widget 中读取依赖](#5-在-widget-中读取依赖)
6. [比应用先结束的作用域](#6-比应用先结束的作用域)
7. [关闭你注册的东西](#7-关闭你注册的东西)
8. [必须在启动前完成的工作](#8-必须在启动前完成的工作)
9. [来自调用方的值](#9-来自调用方的值)
10. [可选依赖](#10-可选依赖)
11. [一张图，多种构建](#11-一张图多种构建)
12. [观察这张图](#12-观察这张图)
13. [测试](#13-测试)
14. [值得提前知道的坑](#14-值得提前知道的坑)
15. [什么时候该加上生成器](#15-什么时候该加上生成器)

---

## 1. 安装

纯 Dart 程序——命令行工具、服务端、没有 widget 的包——只需要一个依赖：

```yaml
environment:
  sdk: ^3.10.0

dependencies:
  cobalt: ^0.2.0
```

Flutter 应用再加上绑定包，它会重新导出整个运行时，所以你永远不需要同时导入两个：

```yaml
environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  cobalt: ^0.2.0
  cobalt_flutter: ^0.2.0

dev_dependencies:
  cobalt_test: ^0.2.0
  cobalt_test_flutter: ^0.2.0
```

**从这里出发不会走进死胡同。** 下限是 Dart `^3.10.0` / Flutter `>=3.38.0`，
和 [GUIDE_CODEGEN.zh-CN.md](GUIDE_CODEGEN.zh-CN.md) 要求的完全一样，
所以之后要不要加生成器是一个选择，而不是一次升级——两者如何叠加，见 [§15](#15-什么时候该加上生成器)。

可选，且只在你需要时才加：`cobalt_go_router` 为每段导航流程提供一个作用域，
`cobalt_bloc` 让作用域能关闭 bloc，`cobalt_inspector` 让你在运行时看这张图，
以及 `cobalt_talker` / `cobalt_logging` / `cobalt_logger` 之一用于可观测性。

这里没有任何东西需要 `cobalt_generator`、`build_runner` 或 `cobalt_lint`——它们属于另一个模式。

---

## 2. 你的第一张图

三块东西：类、每个类一个工厂，以及一个把它们注册进去的构建器。

```dart
import 'package:cobalt/cobalt.dart';

class Clock {
  DateTime now() => DateTime.now();
}

class EventLog implements Disposable {
  final entries = <String>[];

  void add(String entry) => entries.add(entry);

  @override
  void dispose() => entries.clear();
}
```

**工厂**是一个对象，而不是闭包。正因如此它可以是 `const`、不持有捕获状态，
并在每次启动之间复用；闭包会捕获你书写它时周围作用域里的东西，
而那正是让第二次启动复用第一次的对象的那个 bug。

```dart
class ClockFactory implements CobaltFactory<Clock> {
  const ClockFactory();

  @override
  Clock create(CobaltResolver resolver) => Clock();
}

class EventLogFactory implements CobaltFactory<EventLog> {
  const EventLogFactory();

  @override
  EventLog create(CobaltResolver resolver) => EventLog();
}
```

依赖在 `create` 内部解析，来自交给你的那个 resolver：

```dart
class ReportFactory implements CobaltFactory<Report> {
  const ReportFactory();

  @override
  Report create(CobaltResolver resolver) =>
      Report(resolver.get<Clock>(), resolver.get<EventLog>());
}
```

**作用域构建器**说明一个作用域里有什么。它只注册，从不解析——
在 `build` 期间解析，读到的会是一张还在被描述的图。

```dart
class AppScope implements CobaltScopeBuilder {
  const AppScope();

  @override
  void build(CobaltScope scope) {
    scope
      ..registerLazySingleton<Clock>(const ClockFactory())
      ..registerLazySingleton<EventLog>(const EventLogFactory())
      ..registerLazySingleton<Report>(const ReportFactory());
  }
}

Future<void> main() async {
  final app = await CobaltApplication.start(root: const AppScope(), rootName: 'app');

  app.get<EventLog>().add('started at ${app.get<Clock>().now()}');

  await app.dispose();
}
```

注册顺序无关紧要。`Report` 可以注册在 `Clock` 之前：`build` 期间什么都不构建，
等到任何东西开始解析时，所有注册都已存在。

没有全局容器。`CobaltApplication.start` 把根交给你，没有任何东西是环境隐式的，
所以同一进程里的两张图互不相关，测试也能并行。

`examples/manual_mode` 就是这些，完整且可运行：

```bash
cd examples/manual_mode && dart run
```

---

## 3. 注册与读取

### 七种注册方式

| 调用 | 何时构建 | 作用域是否持有 |
|---|---|---|
| `registerSingleton<T>(value)` | 已由你构建 | 是 |
| `registerEagerSingleton<T>(factory)` | 立即，由作用域构建 | 是 |
| `registerLazySingleton<T>(factory)` | 首次解析时 | 是 |
| `registerAsyncSingleton<T>(factory)` | 在 `init()` 中，按依赖顺序 | 是 |
| `registerLazyAsyncSingleton<T>(factory)` | 首次 `getAsync` 时 | 是 |
| `registerFactory<T>(factory)` | 每次解析 | 否 |
| `registerParamFactory<T, P>(factory)` | 每次解析，带一个参数 | 否 |

「是否持有」就是全部区别，它也决定了销毁：作用域释放它持有的东西，
而瞬态对象不归它释放——见 [§7](#7-关闭你注册的东西)。

`name` 限定符让同一类型的第二个注册合法，因为键是类型**加**名字：

```dart
scope
  ..registerLazySingleton<Logger>(const AppLoggerFactory())
  ..registerLazySingleton<Logger>(const AuditLoggerFactory(), name: 'audit');
```

在同一个作用域里注册同一个键两次会抛异常。不触发它而替换一条注册有两种方式：
把覆盖交给拥有这个键的作用域，或者在子作用域里注册，为在它之下解析的东西遮蔽它——
见 [§13](#13-测试)。

### 六种读取方式

```dart
scope.get<Repository>();                       // 没有注册就抛异常
scope.getOrNull<Telemetry>();                  // 改为返回 null——见 §10
scope.get<Logger>(name: 'audit');              // 命名注册
scope.getAll<NoteFormatter>();                 // 该类型的全部注册，就近作用域在前
scope.getWithParam<Counter, String>('alice');  // 参数化注册
await scope.getAsync<SearchEngine>();          // 先构建惰性异步注册——见 §8
```

`isRegistered<T>()` 不构建任何东西就能回答。

解析沿树向上：本作用域，然后父级，一直到根。`getAll` 收集整条链，就近者在前，
被遮蔽的键只取一次——取自拥有它的最近那个作用域。

### 查看一个作用域里有什么

这些都是诊断用途，都不会构建任何东西：

```dart
scope.keys;                  // 本作用域自己的注册，按注册顺序
scope.visibleKeys;           // 加上继承来的，并映射到各自的持有作用域
scope.root;                  // 树顶
scope.debugDescribeTree();   // 以文本形式呈现的树
```

`visibleKeys` 是 map 而不是 set，原因值得尽早记住：工厂运行在拥有**它自身那条注册**的作用域上，
而不是你发问的那个。知道哪个作用域持有某个键，才知道一次覆盖会不会被看到——见 [§13](#13-测试)。

---

## 4. 启动 Flutter 应用

根作用域由 `CobaltAppScope` 持有：构建图、发布到 widget 树、卸载时销毁，
并把启动失败变成一个带重试的界面，而不是一个还没画出第一帧就死掉的应用。

把它放进 `MaterialApp.builder`，不要放在 `MaterialApp` 之上。在那里它位于 `Theme`、
`Directionality` 和 `Localizations` 之下，于是 `loading` 和 `errorBuilder` 就是普通界面，
而不是第二个 `MaterialApp`：

```dart
void main() => runApp(
  MaterialApp(
    theme: appTheme,
    builder: CobaltAppScope.builder(
      root: const AppScope(),
      bootstrap: () => [const BindPlatform()],
      rootName: 'app',
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: (context, error, retry) => StartupFailed(error: error, retry: retry),
    ),
    home: const HomeScreen(),
  ),
);
```

`bootstrap` 是函数而不是列表，这是有意的：步骤持有资源，重启必须拿到新的。
存成列表会悄悄把同一批对象交给第二次启动。

`CobaltAppScope.of(context).restart()` 重建整张图——同一个调用也用于重试失败的启动。

如果应用已经有自己的 `builder`，请自己组合，不要指望框架去合并两个：

```dart
builder: (context, child) => CobaltAppScope(
  root: const AppScope(),
  child: myWrapper(child!),
),
```

---

**`build()` 内部的顺序对饿汉式注册有意义，对懒汉式没有。** `registerLazySingleton` 是「稍后再建」的承诺，
所以它不在乎上面或下面注册了什么。`registerSingleton` 是**当场**构建的，它解析的东西必须已经注册。
把手写的 builder 组合在生成的 builder 之上时就会遇到：把饿汉式的放在容器之后，或者改成懒汉式。

## 5. 在 widget 中读取依赖

```dart
final repository = context.cobalt<Repository>();
final formatters = context.cobaltAll<NoteFormatter>();
final counter = context.cobaltWithParam<Counter, String>('alice');
final scope = context.cobaltScope;
```

每一个都从 widget 之上**最近**的作用域开始解析，然后逐级向上；
因此流程作用域或会话作用域中的注册，会对其内部的一切遮蔽根作用域的同名注册。

有一件事最好在被它咬到之前知道：`Navigator.push` 用的是 navigator 的 context，
而不是发起 push 的那个 widget 的 context。如果一个界面读取的 provider 位于发起 push 的界面**内部**，
那么它就地挂载时解析正常，被 push 打开时就会抛 `CobaltNoScopeError`。
这种情况下请显式传入作用域，或者在 provider 之下 push。

---

## 6. 比应用先结束的作用域

框架就是为这件事写的。作用域是树上的一个节点，它拥有自己构建的东西，
销毁它会连带销毁其内部构建的一切。

### 会话

```dart
class SessionManager {
  SessionManager(this._root);

  final CobaltScope _root;
  CobaltScope? _session;

  Future<void> signIn(User user) async {
    _session = _root.push('session:${user.id}')
      ..registerLazySingleton<Draft>(const DraftFactory())
      ..registerLazySingleton<SyncQueue>(const SyncQueueFactory());
    await _session!.init();
  }

  Future<void> signOut() async {
    await _session?.dispose();
    _session = null;
  }
}
```

登出就是 `await scope.dispose()`。没有仓储去订阅会话流，
也没有领域接口被迫长出一个它并不想要的 `reset()`。

`push` 立刻返回子作用域，`init()` 负责构建它的异步注册。
即使没有异步注册也请调用 `init()`：它很便宜、幂等，
而且这样一来以后新增一个异步注册就不必改动调用处。

### 界面

```dart
CobaltScopeWidget(
  name: 'editor',
  builder: const EditorScope(),
  child: const EditorBody(),
)
```

挂载时创建，卸载时销毁。注意：作用域要等 `init()` 完成后才发布，
所以即使是完全同步的图也会渲染一帧 `loading`。

### 导航流程

用 `cobalt_go_router`，生命周期由流程决定，而不是由「你记得放上去的那个 widget」决定：

```dart
class OrderFlowRoute extends CobaltShellRoute {
  OrderFlowRoute()
    : super(
        name: 'order',
        identity: _orderId,
        scope: (state) => OrderFlowScope(_orderId(state)),
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

  static String _orderId(GoRouterState state) => state.pathParameters['orderId']!;
}

class OrderFlowScope implements CobaltScopeBuilder {
  const OrderFlowScope(this.orderId);

  final String orderId;

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<OrderDraft>(OrderDraftFactory(orderId));
}
```

注意这里的 `OrderDraftFactory` 不是 `const`：它带着订单 id。
工厂接受配置是没问题的；它不能做的是捕获周围的图。

在 `summary` 与 `payment` 之间导航共用同一个作用域，离开流程则销毁它。
`identity` 回答的是路由自己判断不了的那个问题：`/orders/1` 和 `/orders/2` 算不算同一个流程。

路由表**只构建一次**，和 router 一起。对 go_router 来说，新的 `CobaltShellRoute` 实例就是另一个流程，
所以每帧重建这个列表就等于每帧重建作用域。

标签页是同样的做法——`CobaltStatefulShellRoute` 和 `CobaltStatefulShellBranch`——
但有一点值得直说：分支是被保持**存活**，不是被保持**可见**。
go_router 会在屏幕外保留分支的 navigator，所以标签页的作用域活到 shell 关闭为止，
而不是活到你切走为止。

---

## 7. 关闭你注册的东西

作用域按**创建**顺序倒序释放它持有的东西，而不是按声明顺序。
这个区别正是手写容器里的 bug：先声明、后创建的组件会被先销毁，而那时还有人依赖它。

Dart 没有结构化类型，所以光有一个签名相同的 `dispose()` 方法是不够的。请说明它是哪个接口：

```dart
class Cache implements Disposable {
  @override
  void dispose() { ... }
}

class Database implements AsyncDisposable {
  @override
  Future<void> dispose() async { ... }
}
```

对于你改不了的类型——来自 SDK、来自别的包、藏在基类后面——在注册处指明如何关闭：

```dart
scope.registerLazySingleton<http.Client>(
  const ClientFactory(),
  dispose: (client) => client.close(),
);

scope.registerAsyncSingleton<Isar>(
  const IsarFactory(),
  dispose: (isar) => isar.close(),
);
```

`dispose:` 只存在于作用域会持有的注册上。`registerFactory` 和 `registerParamFactory` 没有这个参数，
因为瞬态对象不归作用域关闭——这个情况在构造上就无法表达，而不是留到运行时去检查。
如果一个瞬态对象拥有某样东西，那么使用它的人也一并拥有。

### 看着像可关闭、其实不是的 Flutter 类型

`ChangeNotifier.dispose` 与 `Disposable.dispose` 完全一致，但作用域依然看不见它，
因为 Dart 是按名字而不是按形状来匹配接口的。明说即可：

```dart
class Filters extends ChangeNotifier implements Disposable {}
```

对 bloc 来说，`cobalt_bloc` 就是那一行：

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {
  CounterCubit() : super(0);
}
```

mixin 够不着的地方，在注册处写 `dispose: closeBloc`。

之后交给 widget 树时请用 `BlocProvider.value`，绝不要用 `BlocProvider(create:)`：
后者会在卸载时关闭别人交给它的对象，而此时作用域仍然持有它，下次解析就会把一个死对象交出去。

### 当销毁出错时

它按设计是尽力而为的。抛异常的步骤会被记录，其余的照常执行；整棵树共用一个截止时间；
作用域最终一定会到达 `disposed`。没做完的事列在 `CobaltDisposeError` 里——
`failures`、`timeouts`、`hasTimeout`——而不是让第一个错误盖住其余九个。

`adopt` 把「不是依赖、但生命周期绑在作用域上」的对象挂上去——
比如一个没人解析的订阅或定时器：

```dart
scope.adopt(subscription, dispose: (it) => it.cancel());
```

---

## 8. 必须在启动前完成的工作

两个阶段，回答的是不同的问题。

**阶段 0 —— bootstrap 步骤。** 在容器存在之前：平台绑定、远端配置，
以及这张图本身所需要的一切。步骤严格按你列出的顺序执行，且无法注入任何东西——
因为还没有可注入的来源。

```dart
class BindPlatform implements CobaltBootstrapStep {
  const BindPlatform();

  @override
  String get name => 'bind-platform';

  @override
  Future<void> run() async => WidgetsFlutterBinding.ensureInitialized();
}

final app = await CobaltApplication.start(
  root: const AppScope(),
  bootstrap: const [BindPlatform(), LoadRemoteConfig()],
  rootName: 'app',
);
```

跑完之后，根作用域会「收养」这些步骤：打开过资源的步骤会随作用域一起关闭——
而且是最后关闭，排在建立于其之上的一切之后。若某个步骤失败，
已经跑完的那些会按倒序释放，然后错误才被重新抛出，因为此时还没有作用域可以接管它们。

**阶段 1 —— 异步单例。** 在容器内部，按依赖顺序构建：

```dart
class DatabaseFactory implements CobaltAsyncFactory<Database> {
  const DatabaseFactory();

  @override
  Future<Database> create(CobaltResolver resolver) async {
    final database = Database(resolver.get<Config>());
    await database.open();
    return database;
  }
}

scope
  ..registerAsyncSingleton<Database>(const DatabaseFactory())
  ..registerAsyncSingleton<SearchIndex>(
    const SearchIndexFactory(),
    dependsOn: {CobaltKey(Database)},
  );
```

`dependsOn` 是排序的边，不是注入——`Database` 你仍然要在 `SearchIndexFactory.create` 内部解析。
同一层上互不相关的初始化器通过 `Future.wait` 一起跑，只有真正存在依赖的才会等待。
出现环会抛 `CobaltCycleError` 并指出路径，而不是一直挂着。

指向一个已注册但**不是**异步的键是错误，而不是空操作：没有构建可等。
指向**祖先**作用域里的异步注册则是允许的，并会被忽略——
祖先在这个作用域存在之前就跑完了它自己的阶段 1。

`CobaltApplication.start` 在两个阶段都完成后才返回，
所以没有 `allReady()` 要调用，也没有「已注册但尚未就绪」这种状态需要你去推理。

异步注册必须在 `init()` 运行之前就存在。它只取启动那一刻找到的那些，且只运行一次，
所以往一个已经激活的作用域里再注册一个是错误，而不是悄悄永远不构建。
请改为压入一个子作用域并初始化它。

### 第一次被请求时才构建

阶段 1 在启动时构建所有东西。对于一个开销很大、与应用同寿、却只有少数界面需要的对象，
这笔交易并不划算——改为惰性注册，在第一次 `getAsync` 之前什么都不会构建：

```dart
scope.registerLazyAsyncSingleton<SearchEngine>(const SearchEngineFactory());

final engine = await scope.getAsync<SearchEngine>();
```

作用域像对待其他单例一样持有并释放它，顺序按**创建**顺序。
并发调用共享同一次构建。失败的构建不会被记住：每个在等待的调用方都会收到这个错误，
下一次调用会重新尝试。它可以在 `init()` 之后注册，因为它没有可以错过的阶段。

构建完成后可以同步读取。在那之前，`get` 会抛出 `CobaltLazyAsyncError` 并提示使用 `getAsync`——
`getAll` 也一样，它旁边有 `getAllAsync`。惰性工厂可以通过解析器等待另一个惰性注册；
绕回到自身键的链是带路径的 `CobaltCycleError`，而不是卡死。
异步单例不能在 `dependsOn` 中点名一个惰性注册——`init()` 没有东西可等。

`dispose` 会等待进行中的构建，并释放它构建出的东西。超过截止时间仍在运行的构建会像其他超时步骤一样被放弃，
它最终完成时，结果会被立即关闭。

在组件里，`CobaltAsyncBuilder` 在第一个界面构建它时显示 `loading`，之后每个界面都会直接渲染：

```dart
CobaltAsyncBuilder<SearchEngine>(
  loading: const Center(child: CircularProgressIndicator()),
  errorBuilder: (context, error, retry) => RetryView(onRetry: retry),
  builder: (context, engine) => SearchScreen(engine: engine),
)
```

---

## 9. 来自调用方的值

对象的一半来自图，另一半来自构建它的人：

```dart
class CounterFactory implements CobaltParamFactory<Counter, String> {
  const CounterFactory();

  @override
  Counter create(CobaltResolver resolver, String sessionId) =>
      Counter(resolver.get<CounterStorage>(), sessionId);
}

scope.registerParamFactory<Counter, String>(const CounterFactory());

final counter = scope.getWithParam<Counter, String>('alice');
```

参数只有一个。需要多个时，把它们打包成 record——用具名的，这样调用处仍然可读：

```dart
typedef EditorArgs = ({int id, String title, bool draft});

class EditorFactory implements CobaltParamFactory<Editor, EditorArgs> {
  const EditorFactory();

  @override
  Editor create(CobaltResolver resolver, EditorArgs args) =>
      Editor(resolver.get<Notes>(), id: args.id, title: args.title, draft: args.draft);
}

scope.getWithParam<Editor, EditorArgs>((id: 7, title: 'draft', draft: true));
```

参数类型是在调用处检查的，而不是在你的工厂内部：传错类型会抛 `CobaltParamTypeError`，
并点明键、期望的类型和实际传来的东西。合法的子类型会被接受，因为检查的是值而不是类型字面量。

用普通的 `get<T>()` 去解析一个参数化注册会抛 `CobaltParamRequiredError`——参数无处可来。

---

## 10. 可选依赖

```dart
class ReportFactory implements CobaltFactory<Report> {
  const ReportFactory();

  @override
  Report create(CobaltResolver resolver) =>
      Report(resolver.get<Clock>(), resolver.getOrNull<Telemetry>());
}
```

`getOrNull` 只在「没有注册」时返回 null。在 `init()` 之前请求异步单例仍然会抛异常，
不带参数请求参数化注册也一样，因为「尚未就绪」和「根本没有」是两回事——
把它们合并会把一个启动顺序的 bug 变成一个读起来像「不存在」的值。

---

## 11. 一张图，多种构建

在确实需要「这次构建要换一个实现」之前，可以跳过本节。在那之前你的图只有一个环境，
这里的内容都用不上。

`CobaltEnvironment.matches` 就是普通的公开 API，所以选择就是一个 `if`：

```dart
class AppScope implements CobaltScopeBuilder {
  const AppScope(this.environment);

  final CobaltEnvironment environment;

  @override
  void build(CobaltScope scope) {
    scope.registerLazySingleton<EventLog>(const EventLogFactory());

    if (environment.matches(const {'dev', 'test'})) {
      scope.registerLazySingleton<ApiClient>(const FakeApiClientFactory());
    }
    if (environment.matches(const {'prod', 'stage'})) {
      scope.registerLazySingleton<ApiClient>(const LiveApiClientFactory());
    }
  }
}
```

`dev`、`stage`、`prod`、`test` 是常量，不是封闭集合——`CobaltEnvironment('canary')` 行为完全一样。
继承它并重写 `matches`，就能一次激活多个，或者按名字以外的东西来匹配。

在这个模式下，没有任何东西替你检查这些分支。两个 `if` 同时为真会把同一个键注册两次并在启动时抛异常；
两个都为假则会让该类型没有注册，第一次解析会失败并说明原因。
这就是本模式的取舍——另一个模式会在构建期就拒绝这两种情况。

---

## 12. 观察这张图

观察者能看到作用域出现、实例被构建、启动完成、销毁失败。
在创建图的地方传入它们；之后压入的每个作用域都会继承。

```dart
final app = await CobaltApplication.start(
  root: const AppScope(),
  observers: [CobaltLogObserver(const CobaltPrintLogSink())],
);
```

`CobaltPrintLogSink` 写到 stdout，这是应用之外的正确默认值；
`CobaltDeveloperLogSink`（`dart:developer`）才是 Flutter 应用里该用的那个。
`push(name, observers: [...])` 给某一棵子树追加观察者。

回调收到的是 `CobaltScopeRef` 和 `CobaltKey`——描述符，不是活对象——
而回调里抛出的异常会被吞掉：观察不能有能力破坏被观察者。
解析不会被上报：命中缓存是热路径，值得看见的是实例**被构建**这件事。

### 送到哪里去

| 包 | 形态 |
|---|---|
| `cobalt_talker` | 观察者，每个事件家族一种带颜色的日志类型 |
| `cobalt_logging` | 基于 dart.dev `logging` 的 sink |
| `cobalt_logger` | 基于 `logger` 的 sink |

其余都是一个回调的事，所以不会有哪个日志库因为没人写适配包而被挡在外面：

```dart
CobaltLogObserver(CobaltLogSink.from((r) => myLogger.debug(r.message)))
CobaltLogObserver(CobaltLogSink.from((r) => gelf.send(r.toStructured())))
```

记录不只是一个字符串：`level`、`scope`、`key`、`error`、`stackTrace` 和 `kind` 都在里面，
而 `kind` 是一个值——`CobaltEventKind.scopeInitFailed`，而不是一句还得你去解析的话。

### 崩溃上报是另一种形态

让一份报告有用的不是异常本身，而是图在那之前正在做什么。

```dart
observers: [
  CobaltErrorObserver(
    CobaltErrorSink.from((report) => Sentry.captureException(
      report.error,
      stackTrace: report.stackTrace,
      withScope: (scope) => scope.setContexts('cobalt', report.toStructured()),
    )),
  ),
],
```

线索是一个 20 条记录的环形缓冲，各个级别都收，包括日志 sink 会丢掉的逐实例记录。
阈值是 `error` 而不是 `warning`：销毁失败确实意味着泄漏，
但每次小磕碰都去惊动一个付费服务，正是报告从此没人看的原因。用 `reportAt` 调低它。

### 运行时，直接在屏幕上

```dart
final log = CobaltInspectorLog();

// observers: [log]

CobaltInspectorScreen(log: log, scope: context.cobaltScope)
```

三个标签页：带生命周期与归属的实时作用域树；实际已经构建出来的东西；
以及上报过的一切，可搜索、可暂停。打开树不会构建任何东西——
为了显示而去实例化一个懒汉单例，就等于改变了你本来要看的东西。

---

## 13. 测试

第一件要知道的事是个坑，而不是 API。`testWidgets` 在 fake-async 区域里执行测试体，
初始化器里的 `Future.delayed` 在那里永远不会完成。**请在 `setUp` 里构建图**，
把针对整张图的断言放在普通的 `test` 里。

```dart
late CobaltScope scope;

setUp(() async {
  scope = await cobaltTestScope(root: const AppScope());
});
```

`cobaltTestScope` 和 `cobaltTestRoot` 会随测试一起销毁——这恰恰是最容易漏掉的一步，
而漏掉它不会报错，只会泄漏到下一个测试里。

### 检查图是否完整

**这一点在本模式下比在任何地方都重要。** 手写工厂是在 `create` 内部解析的，
静态分析看不到它将要请求什么：缺失的注册是一个运行期故障，
而且会在恰好第一个解析到它的那个界面上暴露出来。跑一遍图是唯一的检查手段：

```dart
await expectGraphResolves(scope);
```

它会报告每一个构建不出来的键，而不只是第一个。它是终局性的——解析**本身**就是检查，
所以跑完之后每个懒汉单例都已构建，销毁顺序也变了。请把它单独放在一个测试里。

参数化注册没有值就无法解析，所以它会以 `unchecked` 的形式被点名列出，而不是被静默跳过。
给它一个样例值，就能真正覆盖到：

```dart
await expectGraphResolves(scope, params: {CobaltKey(Counter): 'alice'});
```

从 Manual Mode 图的第一天起就把这个测试放进测试集。它就是另一个模式从编译器那里免费得到的东西。

### 覆盖依赖

把替换交给拥有这个键的作用域。覆盖在作用域创建时最先注册，
之后同一个键的真实注册会被跳过，而不是当作重复注册报错——
所以这个作用域里的每个工厂拿到的都是替换品：

```dart
final scope = cobaltTestRoot(
  overrides: [CobaltOverride<Clock>.value(FixedClock(DateTime(2026)))],
)..runBuilder(const AppScope());
```

`.value` 接收一个已经构建好的对象，`.lazy` 和 `.transient` 接收工厂，
`CobaltParamOverride<T, P>` 接收参数化工厂。`cobaltTestScope(overrides:)` 和
`CobaltApplication.start(overrides:)` 接收同一个列表；`CobaltAppScope(overrides: () => [...])`
接收一个函数，每次启动都会调用，这样重启拿到的不会是上一个图已经关闭的值。
在应用里，这就是风味构建或调试菜单。覆盖从不静默：观察者会收到 `onRegistrationOverridden`，
`overriddenKeys` 会列出被替换的键。

构建代价高的 eager 单例请用 `registerEagerSingleton` 注册。交给 `registerSingleton` 的值
在作用域来得及拒绝之前就已经存在，所以在覆盖之下它会被保留、随作用域关闭，但永远不会被解析；
`registerEagerSingleton` 让作用域自己去构建它——也就可以不构建。

写明类型参数。在列表里 Dart 会把它推断为 `Object`，作用域一创建就会拒绝这样的覆盖。
单独写出来时，它会推断成替换品的类型——`FixedClock` 而不是 `Clock`——
`runBuilder` 会报告这个什么都没替换的覆盖。

从子作用域遮蔽是另一种方式，也是生产环境里会话和流程所用的方式：

```dart
final child = scope.pushForTest()
  ..registerSingleton<Clock>(FixedClock(DateTime(2026)));
```

它只能影响从子作用域解析的东西：**工厂运行在拥有它自身那条注册的作用域上**，
注册在更上层的消费者拿到的仍然是真实依赖。`ownerOf<T>()` 会比断言更早告诉你答案：

```dart
expect(scope.ownerOf<Greeter>(), same(scope.root));   // 属于根，就在根上覆盖
```

### 测试替身

```dart
final scope = cobaltTestRoot()
  ..registerLazySingleton<Clock>(FnFactory((_) => FixedClock(DateTime(2026))))
  ..registerSingleton<Config>(const Config())
  ..registerAsyncSingleton<Db>(AsyncFnFactory((_) async => Db()))
  ..registerParamFactory<Counter, String>(FnParamFactory((_, id) => Counter(id)));

await scope.init();
```

这四个让你不必为每个桩对象都写一个工厂类。异步注册必须在 `init()` **之前**就存在——
所以测试替身要放进一个新的根作用域，而不是一个已经启动的作用域。

`DisposeRecorder` 是用于销毁断言的替身，它的日志是按实例而非共享的：
某个测试结束后才销毁的作用域，无法把记录写进下一个测试。

```dart
final recorder = DisposeRecorder();
scope.registerLazySingleton<Disposable>(recorder.factory('cache'));
scope.get<Disposable>();

await scope.dispose();
expect(recorder.entries, ['cache']);
```

`CapturingObserver` 收集事件，供你断言这张图做过什么。

### widget 测试

`cobalt_test_flutter` 提供了两个「显而易见的写法恰好是错的」的辅助函数：

```dart
await settle(tester);                    // 不是 pumpAndSettle：它在加载指示器上会一直转下去
final scope = mountedRootScope(tester);  // 应用的图，取自 MaterialApp builder 之下
```

`examples/testing_patterns` 这个包的全部意义就在它的 `test/` 目录里。

---

## 14. 值得提前知道的坑

每一条都是付出代价才发现的——在这个仓库里，或在它当初为之而写的那些应用里。

- **测试集里没有 `expectGraphResolves`。** 在这个模式下，没有别的东西检查图是否完整。
  缺失的注册会被发布出去，并在某个界面上失败。
- **在 `testWidgets` 内部构建图。** fake-async，什么都完成不了，超时了还找不到原因。用 `setUp`。
- **在消费者之下做覆盖。** 工厂运行在持有该注册的作用域上。`ownerOf<T>()` 比断言更早告诉你。
- **工厂去捕获而不是去解析。** 请从传给 `create` 的 `resolver` 读取协作对象，
  而不是从书写工厂处周围的变量读取，否则第二次启动会复用第一张图的对象。
- **在 `CobaltScopeBuilder.build` 里解析。** 它运行时作用域还在被描述。那里只注册，稍后再解析。
- **用 `CobaltAppScope` 持有根时，把 `bootstrap` 写成存下来的列表。** 步骤持有资源，
  重启必须拿到新的。传一个函数。
- **对作用域持有的 bloc 使用 `BlocProvider(create:)`。** 两个所有者，而 widget 先动手。
  用 `BlocProvider.value`。
- **注册了 `ChangeNotifier` 或 `Cubit` 却没声明它可关闭。** 被构建、被使用、永不关闭，且悄无声息。
  用 `implements Disposable`、`with CobaltBloc` 或 `dispose:`。
- **PATH 里旧版 `dart` 排在前面。** 它出错时既不响亮也不在正确的位置。
  在相信一次运行结果之前先看 `dart --version`。

---

## 15. 什么时候该加上生成器

这里写的任何东西都不必扔掉。生成的容器就是一个和上面那些一样的 `CobaltScopeBuilder`，
所以它能和你已经写好的东西组合：

```dart
class AppScope implements CobaltScopeBuilder {
  const AppScope();

  @override
  void build(CobaltScope scope) {
    $CobaltRootScope().build(scope);          // 生成器找到的部分
    scope.registerSingleton<Config>(config); // 它无从知晓的部分
  }
}
```

当图变大时，有三件事让构建步骤变得值得：

- **完整性在构建期被检查**，而不是靠测试期的 `expectGraphResolves`；
- **属性注入**，让已经长到五个以上协作对象的构造函数清空；
- **十四条 lint 规则**，在编辑器里就抓住 §14 里的那些错误。

保持原样不变的部分：作用域、销毁、两个阶段、参数化注册、可观测性、测试。
[GUIDE_CODEGEN.zh-CN.md](GUIDE_CODEGEN.zh-CN.md) 从这里接着讲，
[MIGRATION.zh-CN.md](MIGRATION.zh-CN.md) 则讲从 `get_it` 或 `injectable` 过来的情况。
