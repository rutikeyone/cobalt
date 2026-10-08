<p align="center">
  <a href="OVERVIEW.md">English</a> · <a href="OVERVIEW.ru.md">Русский</a> · <a href="OVERVIEW.zh-CN.md">中文</a> · <a href="OVERVIEW.ko.md">한국어</a>
</p>

> 本文档译自 [OVERVIEW.md](OVERVIEW.md)。英文版为准：若有出入，以英文为准。

# 深入了解 Cobalt

[README](../README.zh-CN.md) 没有展开的内容：全部特性、内部如何工作、兼容性承诺覆盖什么，以及它的开销。

## 它是什么

一个拥有自己所构建之物的容器。作用域构成一棵树而不是一个栈，
因此会话、结账流程和界面各有自己的生命周期，结束其中之一会连带结束在它内部构建的一切——
登出就是 `await scope.dispose()`，而不是九处对会话流的订阅，
外加四个渗进领域接口的 `reset()` 方法。

代码生成是这套运行时之上的便利，而不是第二个框架。生成器写出的正是你会手写的东西，
除了 `cobalt` 的公开 API 之外什么都不用——这正是渐进式迁移得以可能的原因：
生成的容器和手写的容器可以组合在同一张图里。

## 特性

| | |
|---|---|
| **层级作用域** | 是树而不是扁平的栈——两棵互不相关的子树可以并存，而栈表达不了这一点 |
| **所有权与销毁** | 作用域释放它构建的东西，按**创建**顺序倒序，尽力而为，整棵树共用一个截止时间 |
| **两阶段启动** | `@CobaltBootstrap` 在容器存在之前，`@CobaltInit` 在容器内部，`start` 返回前两者都已完成 |
| **惰性异步单例** | 由第一次 `getAsync` 构建，而不是在启动时——适合开销大、与应用同寿、却只有少数界面需要的对象 |
| **异步瞬态** | `registerAsyncFactory`，或在 `@CobaltInit` 类上加 `@cobaltTransient`：每次 `getAsync` 都构建并等待一个新实例，作用域不持有它 |
| **拓扑排序** | 异步初始化器按 Kahn 算法分层；互不相关的分支通过 `Future.wait` 并行，出现环则构建失败并指出这个环 |
| **属性注入** | `late final` 字段由生成的 mixin 填充，于是有五个协作对象的类拥有一个空构造函数 |
| **编译期完整性** | 没有人注册的依赖会让构建失败，并一次性点出所有缺口 |
| **参数化注册** | `@CobaltParam` 表示由调用方提供的部分；生成器把参数类型写成具名 record。用在 `@CobaltInit` 类上时构建是异步的，用 `getAsyncWithParam` 等待 |
| **可选依赖** | `Foo?` 通过 `getOrNull` 解析，注入 null 而不是让构建失败 |
| **模块** | 注册不是你写的类型——别的包里的客户端、SDK 交给你的值 |
| **装饰器** | 包装注册交出的对象——日志、重试、缓存——不改动它的类，可以手写，也可以用 `@CobaltDecorates`；包装一条注册或某类型的所有注册 |
| **钩子** | 看到图构建的每一个某超类型的实例——比如每个 `Loggable` 都加入注册表——不论由哪条注册构建，可手写也可用 `@cobaltHookAll`；与装饰器不同，它不能替换实例 |
| **环境** | 同一个抽象，按构建给出不同实现，重叠会在构建期被拒绝 |
| **命名注册与多重注入** | `@Named` 限定符，以及遍历某类型全部注册的 `getAll<T>()` |
| **可观测性** | 类型化事件而不是字符串——日志、结构化上报，以及带线索的崩溃报告 |
| **应用内检查器** | 实时作用域树、构建了什么及其生命周期，以及上报过的一切 |
| **导航流程** | 生命周期即一段 go_router 流程的作用域，并且没有任何东西去镜像路由 |
| **lint 插件** | 十八条规则，建立在生成器所用的同一套解析层上 |
| **依赖覆盖** | 在注册所属的作用域里替换它，让每个消费者都看到替身——无论是在测试、风味构建还是调试菜单里 |
| **测试辅助** | 随测试一起销毁的作用域，以及与生产环境同一套机制的依赖覆盖 |
| **没有全局容器** | 没有任何东西是环境隐式的，所以测试可以并行，同一进程里的两张图互不相关 |

## 环境要求

**每个包都要求 Dart `^3.10.0`，需要 Flutter 的那些则写 `>=3.38.0`。** 全部十五个，
包括生成器和 lint 插件——仍停留在 Flutter 3.38 的应用拿到的是两种模式，而不只是 Manual Mode。

在 Flutter 3.38.9——也就是下限本身——上开发，并在当前的 `stable` 和 `beta` 上检查。

这个下限背后的机制值得了解，因为真正卡住的并不是 Dart 版本。
**Flutter 3.38 把 `meta` 钉在 1.17.0，而 analyzer 10.0.2 需要 `^1.18.0`**——
所以运行在 3.38 上的 Flutter 应用最高只能拿到 analyzer 10.0.1，无论它的 SDK 约束怎么写。
纯 Dart 的使用者不受此限制，会拿到 12.1.0；13.0.0 对两者都够不着，
因为它依赖 `_fe_analyzer_shared 100`，后者需要 Dart 3.11。

因此三个工具链包声明的是 `analyzer: ">=10.0.1 <15.0.0"`，而不是单一版本，
同一份源码在这个区间的每一行上都能构建并通过测试。每个读取 analyzer 的包都会精确钉住它，
所以你拿到哪一行由你的项目决定，而不是由我们决定：

| 你的项目 | analyzer | analyzer_plugin | analysis_server_plugin | analyzer_testing | dart_style |
|---|---|---|---|---|---|
| Flutter 3.38 | 10.0.1 | 0.14.1 | 0.3.7 | 0.1.9 | 3.1.7 |
| 更新的版本，只要没有别的依赖需要 analyzer 13 | 12.1.0 | 0.14.8 | 0.3.14 | 0.2.5 | 3.1.8 |
| Flutter 3.49 的 `test`、`build` 4.0.8+、较新的 `freezed` 或 `json_serializable` | 13.x – 14.x | 0.14.9 – 0.14.17 | 0.3.15 – 0.3.23 | 0.2.6 – 0.4.2 | 3.1.9 – 3.1.13 |

生成器以固定的语言版本 3.10 进行格式化，而不是用解析到的 `dart_style` 认为的最新版本——
因此每一行产出的字节都相同，为更新语言版本新增样式规则的格式化器版本也改变不了已提交的内容。
这一点是检查出来的，而不是假设的：CI 的 `verify` job 在 Flutter 3.38.9 上重新生成——
`codegen_basics` 落在 10.0.1 这一行，兼容性试验台落在 12.1.0——并与已提交结果做 diff；
`beta` 上的 `forward` job 解析到最新一行，也会对同样的文件做 diff。

本仓库就在这个下限上开发，这也是它不是 pub workspace 的原因。workspace 是一次解析，
而在 Flutter 3.38 上 `flutter_test` 把 `test_api` 钉在 0.7.7，这把 `test` 运行器限制在 1.26.3、
analyzer 限制在 9 以下，而 `cobalt_analyzer` 需要 10.0.1。所以每个包各自解析，
并从 `tool/overrides.py` 写出的 `pubspec_overrides.yaml` 中取用同仓库的包。
CI 的 `verify` job 在 Flutter 3.38.9 上运行全部检查，`forward` 则在 `stable` 和 `beta` 上运行，
提前发现即将到来的问题，而不是跑历史版本矩阵。

## 兼容性

只有主版本才会破坏兼容，其 CHANGELOG 会在 **Breaking** 下列出。在 0.x 阶段任何次版本都可能带来破坏性变更；
自 1.0 起不再如此。具体有三条规则：

- **公开枚举新增取值属于次版本变更。** `CobaltRegistrationKind` 已在三个版本中增长，以后还会增长。请使用
  它的属性——`isRetained`、`takesParam`、`isAsync`、`isBuiltByInit`——而不是对取值做 `switch`；
  穷尽式 `switch` 需要你自己更新。
- **`CobaltResolver` 不能在 Cobalt 之外实现。** 它是 `base` 类，所以新的解析方式可以在次版本中加入。
  测试里请构建真实的作用域——`cobalt_test` 的 `cobaltTestRoot`——而不是 mock。
- **新增观察者钩子属于次版本变更。** `CobaltObserver` 是带空钩子的基类，针对旧版本写的观察者依然能编译
  （`onInstanceBuilt` 就是这样加入的；`CobaltHook` 也是这样设计的）。你*实现*的东西——工厂、装饰器、日志接收器、`Disposable`——
  只会在主版本中新增成员。

有两样东西被有意排除在这些规则之外。`CobaltScope` 的 `debugResolve…` 成员是检查器和 `cobalt_test` 进行解析的途径，
标注了 `@experimental`，可能在次版本中变化；较新的分析器会在其他包每次使用它们时报告 `experimental_member_use`，
这正是用意：在有意使用的地方忽略即可。`cobalt_analyzer` 是生成器和 lint 插件的内部包：它的 API 跟随二者的需要，而不是
semver；请依赖它们，而不是它。

只读的 `debug…` 成员（`debugKindOf`、`debugDescribeTree` 等）不属于例外：1.2 已将它们弃用，改用 `registrationOf`、
`describeTree()` 及其余检查 API；和任何弃用成员一样，它们在整个 1.x 中保持不变，并将在 2.0 中移除。

从更早的 0.x 升级：[MIGRATION](../MIGRATION.zh-CN.md#从-cobalt-0x-到-10) 列出了每个会让代码无法编译的变化，以及如何处理。

`tool/api.sh` 会报告每个包相对 pub.dev 上版本的变化；`tool/class_modifiers.txt` 记录每个公开类型的类修饰符——
这正是该工具看不到的变化——修饰符改了却没记录时 CI 会失败。

## 性能

Cobalt 与 get_it 的对比，来自 [`benchmark/`](../benchmark/README.md)，每一行做了什么在那里有说明。
AOT 编译，arm64，Dart SDK 3.10.8（stable，`macos_arm64`）。
取三次运行的中位数；三次结果相差在百分之十以内。

| | Cobalt | get_it | Cobalt / get_it |
|---|---:|---:|---:|
| get 已构建的单例 | 81 ns | 425 ns | 0.19× |
| 构建带两个依赖的 transient | 356 ns | 1.22 µs | 0.29× |
| 注册 200 个，再各 get 一次 | 137 µs | 386 µs | 0.35× |
| 启动 20 个异步单例 | 24.7 µs | 28.1 µs | 0.88× |
| 同一 transient，带空观察者 | 374 ns | — | — |
| 同一 transient，带记录型观察者 | 860 ns | — | — |
| 同一 transient，带默认级别的日志观察者 | 385 ns | — | — |

最后一列小于 1，表示 Cobalt 用时更少。绝对数值只属于这台机器；
能迁移的是数量级。一次解析远低于一微秒，200 个注册的图不到一毫秒，二十个单例的异步启动在几十微秒——
与 16 ms 的一帧相比都微不足道。把每个事件转成记录的观察者大约让一次构建的开销翻倍；默认级别的日志观察者则不会——它丢弃的每个实例的记录
根本不会被创建，开销与什么都不覆盖的观察者相同。

```
cd benchmark && dart compile exe bin/main.dart -o /tmp/cobalt_benchmark && /tmp/cobalt_benchmark
```

## 它如何工作

### 作用域拥有它构建的东西

作用域是一个节点，有父节点、子节点和自己的注册项。解析沿树向上，
因此子作用域中的注册会遮蔽上层的同名注册——生产环境中会话的仓储就是这样替换掉匿名仓储的。
工厂运行在拥有它那条注册的作用域上，所以遮蔽只影响在它之下解析的东西；
要为所有消费者替换一个依赖，就把覆盖交给拥有这个键的作用域，那里的真实注册会被跳过。

销毁按**创建**顺序倒序，而不是声明顺序。这个区别正是多数手写容器里的 bug：
先声明、后创建的组件会被先销毁，而那时还有人依赖它。销毁是尽力而为的：
抛异常的 `dispose` 会被记录、其余照常执行，整棵树共用一个截止时间，
没做完的事列在 `CobaltDisposeError` 里，而不是让第一个错误盖住其余九个。

父作用域强引用子作用域。弱引用曾被考虑并否决：它会允许子作用域在 `dispose()` 运行前被回收，
也就是永远不运行；而且它根本防不住泄漏——内部的活对象自己就撑着自己。

### 图在构建之前就被检查

Code-Gen Mode 在构建期拒绝不完整的图，并在一条消息里点出所有缺口：

```
Diagnostics requires DeviceInfo, which nothing registers. Annotate the class that
provides it with @CobaltInject, or name it in @CobaltScopeRoot(provides: [...]) when
something outside the generated container registers it.
```

构造参数、`@injected` 字段和 `@CobaltInit(dependsOn:)` 都算在内，`@Named` 限定符是键的一部分，
每个环境分别检查。重复注册、依赖环、同一个包里两个作用域根、没有列出 `instantiations` 的泛型可注入类、抽象类，同样都是构建失败。

这是 Code-Gen 才有的保证，边界也说得很老实：手写工厂在 `create` 内部解析，
静态分析看不到它将要请求什么。Manual Mode 的图仍然会在运行时失败——
`cobalt_test` 里的 `expectGraphResolves` 正是为这个缺口准备的。

### 生成的代码就是你本来会写的代码

三个构建器：一个写属性注入的 mixin，一个把每个库扫描成 IR，一个把整个包聚合成 `lib/cobalt.g.dart`。
聚合之所以分两阶段，是因为单个构建步骤看不到整个程序。

产物是私有 const 工厂类和一个 `$CobaltRootScope`，其顺序由编译期拓扑排序确定——
没有闭包、没有反射、没有运行时扫描。`$cobaltBootstrap` 是 getter 而不是存下来的列表，
所以重启拿到的是新的步骤，而不是上次启动已经用掉的那些。

泛型作为依赖和 `exposeAs` 目标都可用：`Repository<User>` 和 `Repository<Order>` 是两条注册，
因为 `CobaltKey` 由 `Type` 构成，而它们是不同的类型。可注入类本身也可以是泛型，
只要列出要注册的具体实例化；每一个都会成为独立的注册，并用各自的 `Store<Note>` 或 `Store<User>` 构建：

```dart
@CobaltInject(instantiations: [Cache<Note>, Cache<User>])
class Cache<T> {
  Cache(this.store);
  final Store<T> store;
}
```

每个类型实参都要写全，`exposeAs` 和 `@injected` 字段都不能与 `instantiations` 一起用。

`cobalt_analyzer` 的存在是为了让生成器和 lint 插件用**同一套**实现解析 Cobalt 声明，而不是两套迟早会
各说各话的实现。它持有 IR 和拓扑排序，并且既不依赖 `build`，也不依赖插件 API。

**项目不变量：** 生成的代码只允许使用 `cobalt` 的公开 API。一旦生成需要 Manual Mode 无法表达的东西，
那就是两个共用一个名字的框架了。

### 可观测性是类型化事件

`CobaltObserver` 汇报这张图在做什么——作用域出现、实例被构建、启动完成、销毁失败。
回调收到的是描述符而不是活对象，因为一个能在销毁进行到一半时从作用域里解析东西的观察者，
就不再只是在观察了；回调抛出的异常会被吞掉：观察不能有能力破坏被观察者。

记录把 `kind` 作为值而不是一句话来携带，这正是结构化上报端能够以
`CobaltEventKind.scopeInitFailed` 为键、而不必解析散文的原因。日志 sink 只是一个回调，
所以不会有哪个日志库因为缺少适配包而被挡在外面；崩溃上报则自成一种形态，
因为让报告有用的是「图在那之前正在做什么」这条线索。

没有注册任何观察者时，每个事件的代价是一次空列表判断。

### 导航流程

`cobalt_go_router` 让作用域的生命周期成为一段导航流程：进入流程时创建，离开时销毁。
它就是一个普通的 `ShellRoute` 子类，作用域由其内部的一个 widget 持有——
没有任何东西去监听并镜像路由，因为手写版本恰恰是在镜像这件事上，
栽在返回键、深链接和标签页切换上的。

由没有公共路径的顶层路由组成的流程——`/cart`、`/checkout`、`/payment`——同样是一个 shell：
`ShellRoute` 本身没有路径，URL 保持声明时的样子。仍然覆盖不到的只有被两个流程共用的路由，
以及由运行时而不是路由表决定边界的流程——见该包的 README。

## 示例

一个应用把它们全部跑起来：

```bash
cd examples/gallery && flutter run
```

画廊是按**能力**而不是按项目组织的——读者来这里是想知道作用域如何结束，
而不是想看 `notes_app`。六个分区，十七个条目：

| 分区 | 条目 |
|---|---|
| 启动 | 两阶段启动 · 环境 · 惰性异步 · 异步瞬态 |
| 注入 | 属性注入 · 命名与多重注入 · 装饰器 |
| 作用域与生命周期 | widget 持有的作用域 · 会话作用域 · 作用域树 · 导航流程 · 销毁 |
| 代码生成 | 生成的容器 · Manual Mode |
| 可观测性 | 图事件 · 应用内检查器 |
| 测试 | 测试范式 |

每个带界面的条目都用**属于自己的**图打开：进入时构建，离开时销毁。
同时打开两个，它们的作用域树互不相关——而这正是画廊真正想展示的东西。
三个没有界面的条目（`销毁`、`Manual Mode`、`测试范式`）展示的是控制台输出而不是一个按钮，
因为一个声称能「打开」命令行程序的画廊是在说谎。

画廊本身用英语、俄语、中文和韩语书写，可在首页切换——它挂载的每一个界面同样如此。
每个示例包都带着自己的 `l10n/*.arb` 并生成自己的 delegate，
由画廊连同自己的和检查器的一起收集；一个多包 Flutter 应用就是这个样子。

框架自身的日志记录仍然是英文，屏幕上的标识符也是——步骤名、作用域名、注册键、生命周期。
哪些内容保留 Cobalt 自己的措辞、为什么，见
[`cobalt_inspector` 的 README](../packages/cobalt_inspector/README.md)；
示例如何接线，见[画廊的 README](../examples/gallery/README.md)。

lint 插件的十八条规则列在 [`cobalt_lint` README](../packages/cobalt_lint/README.md) 和
[GUIDE_CODEGEN.zh-CN.md](../GUIDE_CODEGEN.zh-CN.md#16-lint-插件) 中。
