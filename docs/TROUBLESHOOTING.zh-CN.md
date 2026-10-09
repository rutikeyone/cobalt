<p align="center">
  <a href="TROUBLESHOOTING.md">English</a> · <a href="TROUBLESHOOTING.ru.md">Русский</a> · <a href="TROUBLESHOOTING.zh-CN.md">中文</a> · <a href="TROUBLESHOOTING.ko.md">한국어</a>
</p>

> 本文档译自 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。英文版为准：若有出入，以英文为准。错误消息里的链接指向英文版；这里的标题与英文版相同，按错误名搜索即可找到对应条目。

# 常见错误

Cobalt 在运行时抛出的每个错误，末尾都带着指向本页对应条目的链接。每个条目说明错误何时出现、该怎么办。

- [从图中读取](#从图中读取)
- [注册](#注册)
- [启动与停止](#启动与停止)
- [在 Flutter 中](#在-flutter-中)
- [`build_runner` 失败时](#build_runner-失败时)
- [第一次构建](#第一次构建)

## 从图中读取

### CobaltNotRegisteredError

```
Config is not registered in scope "app" or its ancestors. Resolving: Api -> Repository -> Config.
Nothing in this scope tree registers Config. Register it, or if it is a @cobaltInject class, run
build_runner again.
```

请求了一个从当前作用域到根作用域都没有注册的类型。

- 使用生成器：给这个类加上 `@cobaltInject`，再运行一次 `dart run build_runner build`。如果这个类型是在生成的容器之外手写注册的，把它写进 `@CobaltScopeRoot(provides: [...])`。
- 手写注册：在该作用域的 `build()` 里注册它，或在上层作用域里注册。
- `Resolving:` 按先后列出是谁在请求。从第一个名字开始查。
- 调用链之后是一条提示。如果当前作用域下层或旁支的作用域注册了这个键，消息会列出其中最多三个：解析只向上查找，从不向下，所以把注册移到上层，或从那个作用域解析。如果同一类型以其他名称注册过，消息会列出这些键，例如 `Api, Api(fake)`：检查 `name:`。两者都没有时，消息会说明整个作用域树都没有注册它：参见前两条。错误对象的 `registeredElsewhere` 和 `sameType` 字段提供同样的信息。
- 如果消息说作用域还在构建中：一个 eager 的 `registerSingleton` 在 `build()` 后面的注册完成之前就解析了它的依赖。把它挪到那些注册之后，或改成 lazy。
- 作用域只能看到自己和上层作用域。注册在会话或屏幕作用域里的类型，从根作用域看不到。

### CobaltNotReadyError

一个异步注册——`registerAsyncSingleton` 或带 `@CobaltInit` 的类——在 `init()` 构建完它之前就被读取了。

- 等待启动完成：`await CobaltApplication.start(...)` 或 `await $startCobalt()`。在 Flutter 中，`CobaltAppScope` 在图就绪之前显示 `loading`，所以要在应用内部读取，而不是在 `runApp` 之前。
- 对于自己 push 的作用域，读取前先 `await child.init()`。

### CobaltLazyAsyncError

一个惰性异步注册——`registerLazyAsyncSingleton` 或惰性的 `@CobaltInit` 类——在被构建之前就用 `get` 读取了。

- 使用 `await scope.getAsync<T>()`。第一次调用会构建它，之后的调用拿到同一个实例。在 widget 里，`CobaltAsyncBuilder` 负责等待。
- 如果希望在屏幕打开时它已就绪，用 `warmUp` 提前启动。

### CobaltAsyncTransientError

对异步 transient——`registerAsyncFactory`，或 `@CobaltInit` 类上的 `@cobaltTransient`——调用了 `get`。它每次调用都会重新构建，所以每次调用都必须等待。

- 使用 `await scope.getAsync<T>()`，列表用 `getAllAsync`。lint 规则 `cobalt_async_transient_read_synchronously` 会在编辑器里标出这里。

### CobaltParamRequiredError

这个注册需要调用方传入一个值——`registerParamFactory`，或带 `@CobaltParam` 的类——但读取时没有传。

- 使用 `scope.getWithParam<T, P>(value)`；异步构建时用 `getAsyncWithParam`。在 widget 里用 `context.cobaltWithParam<T, P>(value)`。

### CobaltNotParameterizedError

相反的情况：对一个不接受参数的注册调用了 `getWithParam`。

- 使用 `get<T>()`。

### CobaltAsyncParamError

对一个根据参数异步构建的注册（`registerAsyncParamFactory`）调用了 `getWithParam`。

- 使用 `await scope.getAsyncWithParam<T, P>(value)`。

### CobaltParamTypeError

传给 `getWithParam` 的值不是这个注册接受的类型。通常是 record 的字段名不同，或顺序不同。

- 传入声明的确切类型。使用生成器时，构造生成的 `$<Class>Args` record。

### CobaltCycleError

```
Dependency cycle detected: Session -> Api -> Session
```

列表里的注册互相依赖，所以哪一个都没法先构建。

- 打破循环：把双方都需要的部分移到第三个类里，或者让一方在使用时再解析另一方，而不是在构造函数里。
- 使用生成器时，循环会让构建失败，lint 规则 `cobalt_dependency_cycle` 会在编辑器里指出它。

## 注册

### CobaltDuplicateRegistrationError

同一个类型、同一个名字在一个作用域里注册了两次。

- 删掉其中一个。
- 要保留同一类型的多个实现，给每个起个名字——注册时 `name: 'audit'`，读取时 `get<Logger>(name: 'audit')`——再用 `getAll<T>()` 一次读出全部。
- 要在测试或 flavor 里替换一个注册，用 override，而不是再注册一次。

### CobaltScopeStateError

作用域所处的状态不适合这次调用。消息会说明是什么状态、请求了什么：

- **`init()` 开始后才做异步注册。** `init()` 只收集它开始时找到的异步注册，并且只运行一次。在 `init()` 之前注册它们。要在之后添加，push 一个子作用域，在那里注册，然后 `await child.init()`。
- **在 `dispose()` 之后或进行中使用作用域。** 有东西持有一个旧作用域的引用——通常是已经退出登录的会话。改为从当前作用域读取。

### CobaltDependsOnError

`dependsOn` 指向了 `init()` 不会构建的东西：没人注册的类型、普通注册、惰性注册或异步工厂。`dependsOn` 只用来排列 `init()` 中异步单例的顺序，所以这里没有可等待的。

- 如果没人注册它，就注册它——和 [CobaltNotRegisteredError](#cobaltnotregisterederror) 的做法一样。
- 否则把它从 `dependsOn` 里去掉。普通依赖在需要时解析，惰性的由第一次 `getAsync` 构建，异步工厂每次 `getAsync` 都构建。

### CobaltOverrideError

override 什么也没替换。

- **没有类型参数。** `CobaltOverride.value(FakeClock())` 替换的是 `FakeClock`——在列表里则是 `Object`。写明被注册的类型：`CobaltOverride<Clock>.value(FakeClock())`。lint 规则 `cobalt_override_needs_type_argument` 能抓到它。
- **作用域不对。** 这个类型注册在另一个作用域，消息里写着是哪个。把 override 放到那里，使用这个类型的工厂才能看到它。

### CobaltDecoratorError

装饰器加得太晚，或者什么也没包装。

- **太晚：** 实例已经交出去了，持有它的一方会留着未装饰的那个。在与注册相同的 `build()` 里、在任何人解析它之前添加装饰器。
- **什么也没包装：** 这个作用域没有注册这个 key。如果另一个作用域注册了，消息会写出是哪个——到那里去装饰。

### CobaltHookError

`hookAll` 是在作用域（或它下面的作用域）已经构建了实例之后才调用的。那些实例永远不会经过这个 hook。

- 先添加 hook，在组装作用域的地方、在任何 `get` 或 eager 注册之前。lint 规则 `cobalt_hook_added_too_late` 能在同一个代码块里抓到它。

## 启动与停止

### CobaltBootstrapError

一个 bootstrap 步骤——`@CobaltBootstrap` 或 `CobaltBootstrapStep`——抛出了异常。消息写明步骤名并带上原始错误；`cause` 和 `causeStackTrace` 保存着它们。

- 修复原始错误。在 Flutter 中，`CobaltAppScope` 会显示带重试按钮的 `errorBuilder`。

### CobaltInitTimeoutError

启动超过了 `init(timeout:)` 或 `initTimeout:`。消息列出所有尚未构建完成的东西。

- 查明它们为什么慢。常见原因是没有自带超时的网络请求。
- 第一个屏幕用不到的东西可以离开启动流程：改成惰性的（`registerLazyAsyncSingleton`），首次使用时再构建。
- 或者放宽超时。

### CobaltWarmUpError

`warmUp` 有些注册没能构建。消息逐个列出它们和各自的错误。其余的已经构建好，失败的那些下一次 `getAsync` 会再试。

- 修复列出的错误——它们就是 `getAsync` 本来会抛出的错误。

### CobaltDisposeError

作用域已经释放，但有些对象没能干净地关闭：某个 `dispose()` 抛了异常，或超过了期限。消息列出每一次失败；`hasTimeout` 区分超时和错误。

- 修复抛出异常的 `dispose()`。其他一切仍然被关闭了。
- 如果是超时，让慢的 `dispose()` 变快，或给释放更多时间：`scope.dispose(timeout: ...)`。默认是整棵树 30 秒。

## 在 Flutter 中

### CobaltNoScopeError

`context.cobalt<T>()` 在 widget 上方没有找到作用域。

- 把 `CobaltAppScope` 放进 `MaterialApp.builder`，如 README 的快速开始所示，或者用 `CobaltScopeWidget` 包住这棵子树。
- 用 `Navigator.push` 打开的路由由 navigator 构建，位置在打开它的屏幕之上，所以看不到那个屏幕拥有的作用域。把作用域传给新屏幕，或把作用域放到 navigator 之上。

### CobaltNoAppScopeError

`CobaltAppScope.of(context)`——用于 `restart()`——在 widget 上方没有找到 `CobaltAppScope`。

- 用 `CobaltAppScope` 或 `CobaltAppScope.builder` 启动应用。`CobaltScopeProvider` 只是发布别人拥有的作用域，所以无法重启它。

## `build_runner` 失败时

生成器会用一条说明要改什么的消息停止构建。常见情况：

- **没人注册的依赖。** 修法和 [CobaltNotRegisteredError](#cobaltnotregisterederror) 一样：给类加注解，或把它写进 `@CobaltScopeRoot(provides: [...])`。消息会一次列出所有缺口。
- **一个包里有两个 `@CobaltScopeRoot` 类。** 一个包只有一个生成的根。保留一个。
- **依赖循环。** 见 [CobaltCycleError](#cobaltcycleerror)。
- **带 `@CobaltInject` 的抽象类。** 生成器无法构建它。给具体类加注解，并以接口暴露它：`@CobaltInject(exposeAs: ApiClient)`。
- **带 `@CobaltInject` 的泛型类。** 消息会说这个类声明了类型参数，因此没有唯一的具体化可以注册。请列出它要注册的具体化，并写全每个类型实参：`@CobaltInject(instantiations: [Cache<Note>, Cache<User>])`。列表里裸写的 `Cache` 会被读成 `Cache<dynamic>` 并被拒绝；`exposeAs` 与 `instantiations` 同时出现、泛型类上的 `@injected` 字段也同样会被拒绝，这种字段请改为通过构造函数接收。

检查如何工作，见 [GUIDE_CODEGEN.zh-CN.md](../GUIDE_CODEGEN.zh-CN.md#5-图必须是完整的)；[lint 插件](../GUIDE_CODEGEN.zh-CN.md#16-lint-插件)能在构建之前就在编辑器里显示其中大部分问题。

## 第一次构建

按[快速开始](../README.zh-CN.md#快速开始)走一遍时，新应用可能出现的提示：

- **`Target of URI hasn't been generated: 'cobalt.g.dart'`，以及 `$CobaltRootScope` 不是类。** 生成器还没有运行。执行 `dart run build_runner build`，每次修改注解后再执行一次；开发时用 `dart run build_runner watch` 让文件保持最新。
- **`test/widget_test.dart` 里的 `The name 'MyApp' isn't a class`。** 这个测试是 `flutter create` 生成的，测的是你已经替换掉的计数器应用。删掉它；新应用的测试见 [`examples/hello/test`](../examples/hello/test)。
- **`lib/cobalt.g.dart` 里的 `The imported package 'cobalt' isn't a dependency`。** 生成的代码直接导入运行时，所以应用必须依赖它：`flutter pub add cobalt`。
