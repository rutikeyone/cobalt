<p align="center">
  <a href="COMPARISON.md">English</a> · <a href="COMPARISON.ru.md">Русский</a> · <a href="COMPARISON.zh-CN.md">中文</a> · <a href="COMPARISON.ko.md">한국어</a>
</p>

# Cobalt 与其他包

Dart 或 Flutter 应用的依赖该用哪个包，以及什么时候不需要 Cobalt。本页关于其他包的内容于 2026-10-24 对照 pub.dev 和各自的文档核对过，版本为 get_it 9.3.0、injectable 3.0.0、riverpod 3.4.3、provider 6.1.5+1 和 yx_scope 1.2.2。这些包还在变化，[来源](#来源)链接指向它们的最新状态。

## 一句话概括

- **get_it** 是服务定位器：注册一次，在任何地方 `get`。不需要生成代码，用户最多，作用域是一个栈。
- **injectable** 根据注解生成 get_it 的注册代码。
- **riverpod** 管理状态，它的 provider 也承载依赖，带有生命周期和替换。
- **provider** 把对象放进控件树。
- **yx_scope** 手写容器，作用域可以嵌套，由编译器检查。
- **Cobalt** 是一个容器，作用域组成一棵树，并关闭自己构建的一切。生成器运行时检查整个图，手写的代码也加入同一个图。

## 对照

| | Cobalt | get_it | injectable | riverpod | provider | yx_scope |
|---|---|---|---|---|---|---|
| **作用域** | 树：任何作用域都可以有子作用域，包括并列的兄弟 | 一个栈：`pushNewScope`、`popScope`、命名作用域 | get_it 的栈：`@Scope` 生成 `init<Name>Scope` | 一个容器；`ProviderScope` 为子树替换，每个 provider 可 `autoDispose` | 控件子树 | 任意深度嵌套的容器；`ScopeHolder` 创建和丢弃一个 |
| **关闭** | 销毁作用域会关闭它构建的一切，从新到旧 | `popScope` 按注册的逆序销毁作用域里的对象 | `@disposeMethod`、`dispose:` | `ref.onDispose`；没人监听时 `autoDispose` | 控件离开时的 `dispose:` | `drop` 销毁作用域的依赖 |
| **缺少依赖** | `build_runner` 失败并列出所有缺口；手写时在第一次 `get`，或在测试里用 `expectGraphResolves` | 第一次 `get` 时 | 生成时警告；设 `throwOnMissingDependencies: true` 时报错 | 无需注册：provider 是全局声明 | 运行时 `ProviderNotFoundException` | 由编译器检查：依赖是容器的字段 |
| **代码生成** | 可选；生成的和手写的注册在同一个图里 | 无 | 它本身就是生成器 | 可选（`riverpod_generator`） | 无 | 无 |
| **异步启动** | 异步单例按依赖顺序启动，互不依赖的并行，带超时 | 异步单例、`dependsOn`、`allReady()` | `@preResolve`：注册前等待完成 | `FutureProvider`；顺序取决于各自等待什么 | `FutureProvider` 控件 | 异步依赖，随作用域一起初始化 |
| **不依赖 Flutter** | 是 | 是 | 是 | 是（`riverpod`） | 否 | 是（`yx_scope`） |
| **测试中替换** | override 在注册所在处替换它；没有全局容器，测试可以并行 | `allowReassignment`、`reset()`；默认一个全局 `GetIt.I` | 同 get_it | 在 `ProviderContainer` 或 `ProviderScope` 上 override | 在控件外包其他 provider | pub.dev 页面未说明 |
| **pub.dev 点赞 / 30 天下载量** | 5 / 1.6K | 4.7K / 2.4M | 1.5K / 396K | 4.0K / 4.1M | 11K / 1.1M | 72 / 8.6K |

## 什么时候不需要 Cobalt

- **一切都和应用活得一样久。** 没有退出登录，没有拥有状态的流程，几个服务在 `main` 里创建：构造函数或 get_it 更省事。
- **应用已经在用 riverpod。** 它的 provider 已经有生命周期和替换。再加一个容器会把图一分为二，两半都得知道对方。
- **需要成熟的历史。** Cobalt 于 2026-09-30 发布 1.0，用户还不多；get_it、provider 和 riverpod 背后有多年积累的问答。Cobalt 的 API 自 1.0 起稳定，每个小版本都检查破坏性变更，但这是承诺，不是历史。
- **不用生成器，又想比作用域 builder 写得更少。** 手动模式是普通的 Dart，但仍比 `registerSingleton` 写得多。

## 什么时候值得

- 状态属于会话、流程或界面，结束时必须关闭。
- 有几个服务必须在第一帧之前启动，其中一些依赖另一些。
- 缺少依赖应当让构建失败，而不是在某个界面上被用户碰到。
- 测试在没有全局容器的情况下替换一个依赖，并且并行运行。

## 迁移

[MIGRATION.zh-CN.md](../MIGRATION.zh-CN.md) 逐块把 get_it、injectable、flutter_bloc 和 provider 的代码对应到 Cobalt，并列出 Cobalt 没有的东西。

## 来源

核对于 2026-10-24：
[get_it](https://pub.dev/packages/get_it) 及
[其作用域](https://flutter-it.dev/documentation/get_it/scopes)、
[injectable](https://pub.dev/packages/injectable) 及
[`InjectableInit`](https://github.com/Milad-Akarie/injectable/blob/master/injectable/lib/src/injectable_annotations.dart)、
[riverpod](https://pub.dev/packages/riverpod)、
[provider](https://pub.dev/packages/provider)、
[yx_scope](https://pub.dev/packages/yx_scope)。点赞和下载量来自 pub.dev API（`/api/packages/<name>/score`）；riverpod 的数字是 `riverpod` 包本身的，不含 `flutter_riverpod`。
