<p align="center">
  <img src="assets/banner.png" alt="Cobalt — dependency injection for Dart and Flutter" width="880">
</p>

<p align="center">
  <a href="https://pub.dev/packages/cobalt"><img src="https://img.shields.io/pub/v/cobalt?logo=dart&logoColor=white&label=pub&color=5FD4C8" alt="pub package"></a>
  <a href="https://pub.dev/packages/cobalt/score"><img src="https://img.shields.io/pub/points/cobalt?color=5FD4C8" alt="pub points"></a>
  <a href="https://pub.dev/packages/cobalt"><img src="https://img.shields.io/pub/likes/cobalt?color=5FD4C8" alt="pub likes"></a>
  <a href="https://github.com/rutikeyone/cobalt/actions/workflows/ci.yml"><img src="https://github.com/rutikeyone/cobalt/actions/workflows/ci.yml/badge.svg" alt="ci"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="licence"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ru.md">Русский</a> · <a href="README.zh-CN.md">中文</a>
</p>

> 本文档译自 [README.md](README.md)。英文版为准：若有出入，以英文为准。
> 各个包自身的 README 不作翻译——它们是 API 参考。

# Cobalt

面向 Dart 和 Flutter 的依赖注入框架。双模式：声明式代码生成，以及基于同一套运行时的纯 Dart 手写 API。

状态：**第一阶段已完成。** 运行时、Flutter 绑定、注解、分析层、两个生成器和 lint 插件均已实现并覆盖测试。

| | |
|---|---|
| **不用代码生成** | [GUIDE_MANUAL.zh-CN.md](GUIDE_MANUAL.zh-CN.md)——注册由你来写 |
| **用生成器** | [GUIDE_CODEGEN.zh-CN.md](GUIDE_CODEGEN.zh-CN.md)——注解，以及在构建期被检查的图 |
| **从 `get_it` 或 `injectable` 过来** | [MIGRATION.zh-CN.md](MIGRATION.zh-CN.md)——哪些对得上，哪些对不上 |
| **跑起来看看** | `cd examples/gallery && flutter run` |

<p align="center">
  <img src="assets/screenshots/hub.png" width="30%" alt="示例画廊">
  <img src="assets/screenshots/tree.png" width="30%" alt="实时作用域树">
  <img src="assets/screenshots/log.png" width="30%" alt="图上报过的一切">
</p>

<p align="center"><sub>示例画廊、带每条注册生命周期的实时作用域树，以及图上报过的一切——运行中应用里的 <code>cobalt_inspector</code>。</sub></p>

<p align="center">
  <img src="assets/screenshots/flow.png" width="30%" alt="由导航流程持有的作用域">
  <img src="assets/screenshots/flowlog.png" width="30%" alt="每份草稿随其流程一起创建与销毁">
  <img src="assets/screenshots/env.png" width="30%" alt="同一个接口，每种构建一个实现">
</p>

<p align="center"><sub>结账流程持有一个作用域——草稿在流程内部导航时存活，随流程一起消失——以及决定究竟注册哪一个实现的环境。</sub></p>

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
| **拓扑排序** | 异步初始化器按 Kahn 算法分层；互不相关的分支通过 `Future.wait` 并行，出现环则构建失败并指出这个环 |
| **属性注入** | `late final` 字段由生成的 mixin 填充，于是有五个协作对象的类拥有一个空构造函数 |
| **编译期完整性** | 没有人注册的依赖会让构建失败，并一次性点出所有缺口 |
| **参数化注册** | `@CobaltParam` 表示由调用方提供的部分；生成器把参数类型写成具名 record |
| **可选依赖** | `Foo?` 通过 `getOrNull` 解析，注入 null 而不是让构建失败 |
| **模块** | 注册不是你写的类型——别的包里的客户端、SDK 交给你的值 |
| **环境** | 同一个抽象，按构建给出不同实现，重叠会在构建期被拒绝 |
| **命名注册与多重注入** | `@Named` 限定符，以及遍历某类型全部注册的 `getAll<T>()` |
| **可观测性** | 类型化事件而不是字符串——日志、结构化上报，以及带线索的崩溃报告 |
| **应用内检查器** | 实时作用域树、构建了什么及其生命周期，以及上报过的一切 |
| **导航流程** | 生命周期即一段 go_router 流程的作用域，并且没有任何东西去镜像路由 |
| **lint 插件** | 十四条规则，建立在生成器所用的同一套解析层上 |
| **依赖覆盖** | 在注册所属的作用域里替换它，让每个消费者都看到替身——无论是在测试、风味构建还是调试菜单里 |
| **测试辅助** | 随测试一起销毁的作用域，以及与生产环境同一套机制的依赖覆盖 |
| **没有全局容器** | 没有任何东西是环境隐式的，所以测试可以并行，同一进程里的两张图互不相关 |

## 包

| 包 | 依赖 | 是否进入应用 |
|---|---|---|
| `cobalt_annotations` | `meta` | 是 |
| `cobalt` | `cobalt_annotations` | 是，运行时核心，不含 Flutter |
| `cobalt_flutter` | `cobalt`、`flutter` | 是 |
| `cobalt_go_router` | `cobalt_flutter`、`go_router` | 是，可选 |
| `cobalt_bloc` | `cobalt`、`bloc` | 是，可选 |
| `cobalt_talker` | `cobalt`、`talker` | 是，可选 |
| `cobalt_logging` | `cobalt`、`logging` | 是，可选 |
| `cobalt_logger` | `cobalt`、`logger` | 是，可选 |
| `cobalt_analyzer` | `cobalt_annotations`、`analyzer` | 否 |
| `cobalt_generator` | `cobalt_analyzer`、`build`、`source_gen`、`code_builder` | 仅 dev_dependency |
| `cobalt_lint` | `cobalt_analyzer`、`analysis_server_plugin` | 仅 dev_dependency |
| `cobalt_test` | `cobalt`、`test_api`、`matcher` | 仅 dev_dependency |
| `cobalt_test_flutter` | `cobalt_flutter`、`flutter_test` | 仅 dev_dependency |
| `cobalt_inspector` | `cobalt_flutter`、`flutter` | 仅 dev_dependency |
| `cobalt_talker_flutter` | `cobalt_inspector`、`cobalt_talker`、`talker_flutter` | 仅 dev_dependency |

`cobalt_analyzer` 的存在是为了让生成器和 lint 插件用**同一套**实现解析 Cobalt 声明，而不是两套迟早会
各说各话的实现。它持有 IR 和拓扑排序，并且既不依赖 `build`，也不依赖插件 API。

**项目不变量：** 生成的代码只允许使用 `cobalt` 的公开 API。一旦生成需要 Manual Mode 无法表达的东西，
那就是两个共用一个名字的框架了。

## 环境要求

**每个包都要求 Dart `^3.10.0`，需要 Flutter 的那些则写 `>=3.38.0`。** 全部十五个，
包括生成器和 lint 插件——仍停留在 Flutter 3.38 的应用拿到的是两种模式，而不只是 Manual Mode。

也在 Flutter 3.47.1 / Dart 3.13.1 上构建并测试过。

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
这一点是检查出来的，而不是假设的：下限 job 在 3.38.9 上于 10.0.1 和 12.1.0 两行重新生成并与已提交结果做 diff，
解析到最新一行的 `beta` job 也会对同样的文件做 diff。

CI 跑 `stable` 和 `beta`，而不是历史版本矩阵，另外还有一个固定在 Flutter 3.38.9 的 job，
它按每个包、兼容性试验台和每个示例自己声明的下限去解析、分析并测试它们（`tool/floor_check.sh`）。
没有任何东西去验证的下限，就是一个会过期的说法。

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
每个环境分别检查。重复注册、依赖环、同一个包里两个作用域根、泛型可注入类、抽象类——同样都是构建失败。

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
因为 `CobaltKey` 由 `Type` 构成，而它们是不同的类型。但可注入类本身不能是泛型：
没有人告诉生成器该注册哪些具体实例化。

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

## lint 规则

`cobalt_lint` 是 `analysis_server_plugin`，不是 `custom_lint` 插件。它提供十四条 warning 规则，
全部建立在生成器所用的同一套 `cobalt_analyzer` 解析层上，
因此错误会在 IDE 里出现，而不是非等到 `build_runner` 跑完：

| 规则 | 捕捉什么 |
|---|---|
| `cobalt_missing_injection_mixin` | 容器会注册的类上有 `@injected` 字段却没有 `with _$ClassName` |
| `cobalt_injected_field_needs_an_injectable` | 容器根本不注册的类上有 `@injected` 字段 |
| `cobalt_param_needs_an_injectable` | 容器根本不注册的类上有 `@CobaltParam` |
| `cobalt_injected_field_must_be_late_final` | `@injected` 用在可变、非 late 或静态字段上 |
| `cobalt_injectable_must_be_constructible` | `@CobaltInject` 用在抽象类或没有公开生成式构造函数的类上 |
| `cobalt_init_requires_init_method` | `@CobaltInit` 用在没有 `init()` 的类上 |
| `cobalt_bootstrap_requires_run_method` | `@CobaltBootstrap` 用在没有 `run()` 的类上 |
| `cobalt_bootstrap_step_cannot_inject` | 构造函数带必填参数的 bootstrap 步骤 |
| `cobalt_environment_needs_a_registration` | `@CobaltEnvironment` 用在无人注册的类上，此时它静默地什么也不做 |
| `cobalt_dependency_is_not_registered` | 包内无人注册的被注入依赖 |
| `cobalt_dependency_cycle` | 最终依赖到自身的可注入类 |
| `cobalt_registration_is_never_released` | 已注册的类带有作用域看不见的 `dispose()` 或 `close()` |
| `cobalt_resource_is_never_closed` | 注册项持有需要关闭的东西，却没有提供关闭它的办法 |
| `cobalt_lazy_registration_injected_synchronously` | 惰性异步注册被注入到无法等待它的地方——同步或 eager 构造函数，或 `@injected` 字段 |

不使用 `custom_lint`：它的最新版本（0.8.1）被钉在 `analyzer ^8.0.0`，无法与现代 analyzer 共存。
`riverpod_lint` 已迁移到官方的 `analysis_server_plugin`，`cobalt_lint` 亦然。

配置这个插件有两个坑，最好在踩上之前先读一读——见
[GUIDE_CODEGEN.zh-CN.md §16](GUIDE_CODEGEN.zh-CN.md#16-lint-插件)。

## 示例

一个应用把它们全部跑起来：

```bash
cd examples/gallery && flutter run
```

画廊是按**能力**而不是按项目组织的——读者来这里是想知道作用域如何结束，
而不是想看 `notes_app`。六个分区，十五个条目：

| 分区 | 条目 |
|---|---|
| 启动 | 两阶段启动 · 环境 · 惰性异步 |
| 注入 | 属性注入 · 命名与多重注入 |
| 作用域与生命周期 | widget 持有的作用域 · 会话作用域 · 作用域树 · 导航流程 · 销毁 |
| 代码生成 | 生成的容器 · Manual Mode |
| 可观测性 | 图事件 · 应用内检查器 |
| 测试 | 测试范式 |

每个带界面的条目都用**属于自己的**图打开：进入时构建，离开时销毁。
同时打开两个，它们的作用域树互不相关——而这正是画廊真正想展示的东西。
三个没有界面的条目（`销毁`、`Manual Mode`、`测试范式`）展示的是控制台输出而不是一个按钮，
因为一个声称能「打开」命令行程序的画廊是在说谎。

画廊本身用英语、俄语和中文书写，可在首页切换——它挂载的每一个界面同样如此。
每个示例包都带着自己的 `l10n/*.arb` 并生成自己的 delegate，
由画廊连同自己的和检查器的一起收集；一个多包 Flutter 应用就是这个样子。

框架自身的日志记录仍然是英文，屏幕上的标识符也是——步骤名、作用域名、注册键、生命周期。
哪些内容保留 Cobalt 自己的措辞、为什么，见
[`cobalt_inspector` 的 README](packages/cobalt_inspector/README.md)；
示例如何接线，见[画廊的 README](examples/gallery/README.md)。

## 在本仓库上工作

```
dart analyze --fatal-infos .
dart format --output=none --set-exit-if-changed .
(cd packages/cobalt && dart test)
(cd packages/cobalt_flutter && flutter test)
(cd examples/manual_mode && dart test)
(cd examples/codegen_basics && dart run build_runner build && flutter test)
(cd examples/notes_app && dart run build_runner build && flutter test)
(cd packages/cobalt_lint && dart test)
(cd packages/cobalt_test && dart test)
(cd packages/cobalt_inspector && flutter test)
(cd packages/cobalt_talker_flutter && flutter test)
(cd examples/gallery && flutter test)
(cd compat/external_consumer && dart pub get && dart run build_runner build && dart test)
./tool/coverage.sh
```

`tool/coverage.sh` 统计有测试的可发布包的行覆盖率，从最低往高打印，并在**总和**低于下限时失败——85%。
当前数字以脚本打印的为准，这里不再重复：一个每次提交都会变的数字写进散文里就会过时，
而且没有任何东西会检查它——它已经过时过两次了。下限取总和而非逐包，这是有意的：
覆盖率是按包统计的，而代码是共享的，所以 `cobalt_analyzer` 的解析器更多是被
`cobalt_generator` 的测试和 `compat/external_consumer` 驱动的，而不是被它自己的测试集。
逐包下限会逼人把测试写在不该写的地方。用 `COVERAGE_FLOOR=90 ./tool/coverage.sh` 覆盖它。

CI（`.github/workflows/ci.yml`）在 `stable` 和 `beta` 上跑上述全部内容，
并在重新生成两个示例**以及 `compat/external_consumer`** 之后执行 `git diff --exit-code`，
因此过时的生成代码会让构建失败。生成器用与格式检查相同的 `dart_style` 版本格式化自己的产物，
所以两者不会有分歧。

**目录约定。** 一个文件一个公开类型。sealed 的 `CobaltRegistration` 层次是有意的例外：
sealed 层次必须位于同一个库中，所以它的子类是 `part` 文件而不是独立的库。
`compat/external_consumer` 则完全在这条经验法则之外——它是一个刻意**不**作为 workspace 成员、
也不声明 `resolution: workspace` 的包，因此 pub 会像对待第三方项目那样独立解析它。
它的存在是为了从仓库之外保持代码生成流水线的诚实。

**已知的发布警告。** `cobalt_lint` 会报「the name of lib/main.dart should match the name of the
package」。这个入口点是由分析服务器插件 API 固定的——服务器生成的代码会导入
`package:cobalt_lint/main.dart` 并读取其中的 `plugin` 变量。`riverpod_lint` 也带着同样的警告。

## 许可证

MIT。见 [LICENSE](LICENSE)。
