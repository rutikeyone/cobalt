<p align="center">
  <a href="MIGRATION.md">English</a> · <a href="MIGRATION.ru.md">Русский</a> · <a href="MIGRATION.zh-CN.md">中文</a>
</p>

> 本文档译自 [MIGRATION.md](MIGRATION.md)。英文版为准：若有出入，以英文为准。

# 迁移到 Cobalt

没有人会先做一个完全不用依赖注入的 Flutter 应用，然后再去挑框架。你会读到这里，是因为你已经在用
`get_it`，或者 `get_it` + `injectable`，而它在某个地方不再撑得住了。

本指南分为两半：什么能一一对应，以及什么根本对不上。有用的是后一半。

## 让迁移能活下来的唯一原则

**从叶子往里走。** 先注册那些没有任何东西依赖的对象，让 Cobalt 和你原有的容器共存，等根节点下面的一切
都已经属于 Cobalt 之后，最后才动根节点。

Manual Mode 存在的意义正在于此。生成的容器和手写的容器是同一套运行时，所以"迁移到一半"是一种正常状态，
而不是坏掉的状态：

```dart
final app = await CobaltApplication.start(root: const AppScope());

// 还没搬走的一切仍然来自 get_it。只有一行，而且最后才删。
GetIt.I.registerSingleton<Database>(app.get<Database>());
```

请抵挡住先迁移根组件的诱惑。它的边最多，而在它的依赖还不属于 Cobalt 之前，你什么也得不到。

## get_it → Cobalt

### 注册

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
| `allowReassignment = true` 或 `unregister<T>()`，再注册替身 | 在 `start`、`CobaltScope.root` 或测试辅助函数上传 `overrides: [CobaltOverride<T>.value(fake)]` |

看得见的差别是**用工厂对象代替闭包**。它换来两样东西：注册可以是 `const`，而且这张图变成了可检视的
值，而不是被捕获的状态——正是这一点让生成器能产出它、让 linter 能读懂它。

### 生命周期

`allReady()` 和 `isReady<T>()` 没有对应物，也不需要。`CobaltApplication.start` 只有在整张异步图都起来之后
才返回，所以既没有东西需要轮询，也没有超时需要调：

```dart
// get_it
GetIt.I.registerSingletonAsync<Database>(() => Database.open());
await GetIt.I.allReady(timeout: const Duration(seconds: 30));

// Cobalt
final app = await CobaltApplication.start(root: const AppScope());
```

`signalReady` 和手动发信号的模式同样没有对应物。Cobalt 从图本身推导就绪状态，而不是等你来宣布。

### 作用域是树，不是栈

这是真正重要的变化，也是机械式移植会做错的地方。

get_it 的作用域是一个**扁平的 LIFO 栈**：`pushNewScope` 永远压入同一个栈，`get<T>()` 从栈顶往下找。
两棵互不相干的子树——比如两个各有会话的标签页——根本无法表达。

Cobalt 的作用域构成一棵**树**。`push` 创建的是*该*作用域的子节点，解析则沿着父链向上直到根。也就是说：

```dart
final tabA = app.push('tab:a');
final tabB = app.push('tab:b');   // 是兄弟，而不是压在 tabA 上面
```

移植时的实际影响：

- 一对本意是"临时覆盖"的 `pushNewScope`/`popScope` 可以直接搬过来。而那种依赖不相关功能之间栈顺序的用法，
  很可能藏着一个 bug——树结构让这类 bug 不可能发生。
- 释放按**创建顺序**倒序进行，而不是按声明顺序。如果你原来的 teardown 依赖字段的声明顺序，它本来就是脆弱的。
- 谁创建作用域，谁负责释放。不存在环境中隐含的"当前作用域"。

### Cobalt 没有的东西

在决定迁移之前请先知道这些：

- **`registerFactoryParam<T, P1, P2>`** —— Cobalt 的 `registerParamFactory<T, P>` 只接受一个参数，
  多个参数合并成一个 record。请用**具名**形式 `({int id, String title})`：它在调用处和工厂里都保留
  参数名，位置式 record 做不到。只有容器无法知道的值才进 record —— 依赖仍从 resolver 取，
  所以 record 通常比它替换掉的参数列表更短。在 Code-Gen Mode 下这些都不用手写：给参数加上
  `@CobaltParam`，生成器会写出 record 类型、工厂和注册。
- **`registerFactoryAsync`** —— 每次调用都重新异步构建。Cobalt 有惰性异步*单例*
  （`registerLazyAsyncSingleton`，用 `getAsync` 读取）：由第一次调用构建并被持有；
  但没有按调用的异步工厂。请在调用方构建这个值，或注册一个惰性单例来产出每次调用所需的东西。
- **`resetLazySingletons`** —— 请改为释放作用域。在活着的持有者脚下重置实例，正是作用域要防止的那类 bug。
- **全局实例。** 没有 `GetIt.I`。作用域要么被传递、要么被注入、要么通过 `context.cobalt<T>()` 从 widget 树
  里读取。这是有意为之：正是那个全局变量让 get_it 的图无法并行测试。

## injectable → Cobalt

### 注解

| injectable | Cobalt |
|---|---|
| `@injectable` | `@cobaltTransient` —— 每次解析都是新实例 |
| `@singleton` | `@cobaltSingleton` —— eager，在容器装配时构建 |
| `@lazySingleton` | `@cobaltInject` —— 默认值，也是你大多数时候想要的 |
| `@Injectable(as: Foo)` | `@CobaltInject(exposeAs: Foo)` |
| `@Named('a')` | `@Named('a')` |
| `@Environment(Environment.dev)` | `@CobaltEnvironment.dev` —— 需要多个时重复该注解 |
| `@preResolve` | `@CobaltInit()` |
| `@disposeMethod` | `implements Disposable` / `AsyncDisposable` |
| `@factoryMethod` | 第一个公开的生成式构造函数；若需要的不是它，则用 `@CobaltModule` 成员 |
| `@factoryParam` | 构造函数参数上的 `@CobaltParam` |
| `@InjectableInit()` + `configureDependencies()` | `@CobaltScopeRoot()` + 生成的 `$startCobalt()` |

### 形态发生变化的部分

**`@module` 变成 `@CobaltModule`，形态几乎不变。** 依然是一个类，其成员提供你并未编写的类型：

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

三点不同。该类是**带 `const` 构造函数的具体类**而非抽象类，因为 Cobalt 在 `const AppModule()` 上调用
成员，而不是生成子类。**抽象成员会被拒绝**：injectable 用它表示「用类自己的构造函数来构建」，而这正是
`@CobaltInject` 已有的含义，绑定到接口则是 `exposeAs`。异步只由 `Future<T>` 标记，没有 `@preResolve`。

**`dispose:` 取代外来类型的 `@disposeMethod`。** 你自己的类实现 `Disposable`；`Dio` 做不到，
因此由注册来说明如何关闭：`@CobaltInject(dispose: closeClient)`。

**`@Order` 消失了。** injectable 要你声明顺序；Cobalt 自己算。注册由编译期拓扑排序决定顺序，其中属性注入
的字段也算依赖边；出现环时构建失败并指出环本身，而不是一路递归到栈溢出。

**泛型类会被拒绝。** `@CobaltInject class Cache<T>` 是构建错误，因为没有任何信息告诉生成器该注册哪些具体化。
请注解一个具体子类型，或者暴露一个：`@CobaltInject(exposeAs: Cache<Note>)`。泛型*依赖*则完全正常——
`Repository<User>` 和 `Repository<Order>` 是两个独立的注册。

### 你得到的东西

**属性注入**——如果你的控制器有五到十四个构造函数参数，这就是值得迁移的理由：

```dart
// 之前
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

// 之后
@cobaltTransient
class NotesCubit extends Cubit<NotesState> with _$NotesCubit {
  NotesCubit() : super(const NotesState());

  @injected
  late final NoteStore _repository;

  @injected
  late final Telemetry _telemetry;
}
```

mixin 会生成在类的旁边，并在构造完成后立即填充这些字段。字段可以是私有的——part 文件与类在同一个库中。
`late final` 是强制的，所以第二次赋值会抛异常，而不是悄悄换掉一个依赖。

**真正的释放。** 作用域拥有它创建的东西，并按创建的相反顺序拆解它们。登出变成
`await sessionScope.dispose()`——不需要在任何地方监听会话，也不需要把 `reset()` 硬塞进领域接口。

## flutter_bloc 与 provider → Cobalt

两者都不是要整体替换的竞品，而且方向不同。

**`provider` 正是 `CobaltScopeProvider` 已经在做的事。** 如果你只用它把容器往控件树下传递 —— 手写
DI 做的就是这件事 —— 这种用法会消失：`CobaltAppScope` 发布根作用域，`context.cobalt<T>()` 读取它。
如果你用 `ChangeNotifierProvider` 给某个子树一个有生命周期的对象，那就是 `CobaltScopeWidget`，
生命周期归作用域管，而不再是控件的手工记账。

**`flutter_bloc` 完全不会被替换。** bloc 由 Cobalt 构建，仍然由 `BlocBuilder` 渲染。在原本创建它
的地方改为解析：

```dart
BlocProvider.value(
  value: context.cobalt<CounterCubit>(),
  child: const CounterView(),
)
```

需要明说的是释放。作用域释放的是实现了 `Disposable` 或 `AsyncDisposable` 的对象，而 `Cubit` 通过
`Future<void> close()` 关闭 —— 两者都不是。每个类桥接一次即可：

```dart
class CounterCubit extends Cubit<int> with CobaltBloc {}
```

这个 mixin 就是 [`cobalt_bloc`](https://pub.dev/packages/cobalt_bloc)，整个包就是为了这一句话而存在；
手写 `implements AsyncDisposable` 和 `Future<void> dispose() => close();` 效果相同。对于无法混入的
bloc，改为指定函数：`@CobaltInject(dispose: closeBloc)`。另外要用 `BlocProvider.value` 而不是
`BlocProvider(create: ...)`——后者会关闭交给它的对象，而所有权在作用域手里。

`ChangeNotifier` 需要的更少：它的 `dispose` 签名本来就匹配，所以 `implements Disposable` 就是全部
改动。漏掉其中任何一个，对象都会被构建、被使用，然后永远不会关闭，而且悄无声息。完整对照表见
[`cobalt_flutter` README](packages/cobalt_flutter/README.md)。

## 一份可照做的顺序

1. 添加 `cobalt` 和 `cobalt_annotations`；原有容器原地不动。
2. 写一个根 `CobaltScopeBuilder`，放进两三个没有任何东西依赖的叶子服务。在 `main` 中与旧容器并排启动它。
3. 搭桥：把这些实例注册回旧容器，让现有调用点继续工作。
4. 迁移这些叶子的消费者。每迁一个，桥上就少一行。
5. 向内重复。这座桥会单调缩短——如果它不再缩短，剩下的那些边正在告诉你一些关于设计的事。
6. 当桥空了，删掉旧容器，把应用切换到 `CobaltAppScope`。
7. 到这时才考虑代码生成：加入 `cobalt_generator`，一次一个文件地把手写注册换成注解。

第 7 步排在最后是有意的。生成只是运行时之上的便利，而那套运行时你应该早已信任。
