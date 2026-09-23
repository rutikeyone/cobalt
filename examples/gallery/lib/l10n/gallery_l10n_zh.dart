// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'gallery_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class GalleryL10nZh extends GalleryL10n {
  GalleryL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Cobalt 示例';

  @override
  String get tagline => '依赖注入 · 示例';

  @override
  String get lede => '每项能力一个示例。大多数可以直接打开；只能打印输出的示例会展示它们的输出。';

  @override
  String get languageTooltip => '语言';

  @override
  String get allExamples => '全部示例';

  @override
  String get whatItShows => '演示内容';

  @override
  String get openExample => '打开示例';

  @override
  String get copyCommand => '复制命令';

  @override
  String get commandCopied => '命令已复制';

  @override
  String get kindScreen => '界面';

  @override
  String get kindTerminal => '终端';

  @override
  String get whereItLives => '代码位置';

  @override
  String get consoleOutput => '控制台输出';

  @override
  String get testOutput => '测试输出';

  @override
  String get sectionStartup => '启动';

  @override
  String get sectionStartupBlurb => '如何启动依赖图，以及选择启动哪一个';

  @override
  String get sectionInjection => '注入';

  @override
  String get sectionInjectionBlurb => '如何把依赖交给需要它们的对象';

  @override
  String get sectionScopes => '作用域与生命周期';

  @override
  String get sectionScopesBlurb => '依赖图何时出现，又何时消失';

  @override
  String get sectionCodegen => '代码生成';

  @override
  String get sectionCodegenBlurb => '生成器写出什么，以及手写同样的代码';

  @override
  String get sectionObservability => '可观测性';

  @override
  String get sectionObservabilityBlurb => '观察依赖图在做什么';

  @override
  String get sectionTesting => '测试';

  @override
  String get sectionTestingBlurb => '如何替换依赖，以及其中的陷阱';

  @override
  String get startupTitle => '两阶段启动';

  @override
  String get startupTeaches => '启动步骤在容器出现之前运行；异步初始化按依赖图执行。';

  @override
  String get startupPoint1 => '阶段 0 的步骤由根作用域收养，并随它一起释放';

  @override
  String get startupPoint2 => '打开了资源的步骤最后关闭 —— 在建立于其上的一切之后';

  @override
  String get startupPoint3 => '阶段 1 把 @CobaltInit 当作图来等待，因此互不依赖的分支并行执行';

  @override
  String get startupPoint4 => '顺序由 dependsOn 决定 —— 你从不需要自己写出这个序列';

  @override
  String get environmentsTitle => '运行环境';

  @override
  String get environmentsTeaches => '一个接口，每种构建对应不同的实现。';

  @override
  String get environmentsPoint1 =>
      '@CobaltEnvironment 可以重复标注而不是接受一个列表 —— 注册属于一个集合，而启动只挑选其中一个';

  @override
  String get environmentsPoint2 => '两个环境相互重叠的注册会让构建失败，而不是让应用失败';

  @override
  String get environmentsPoint3 => '什么都不选时，被拆分的类型就没有注册，因此这个疏漏会大声报错';

  @override
  String get environmentsPoint4 => '手写模式写出的正是生成器所产生的那个 `if`';

  @override
  String get lazyAsyncTitle => '惰性异步';

  @override
  String get lazyAsyncTeaches => '一个代价高的对象，由第一个请求它的页面构建，而不是在启动时构建。';

  @override
  String get lazyAsyncPoint1 =>
      'registerLazyAsyncSingleton 或 @CobaltInit(lazy: true) 让它不进入 init()，启动从不等它';

  @override
  String get lazyAsyncPoint2 => '第一次 getAsync 构建它；同时请求的调用方都等待同一次构建';

  @override
  String get lazyAsyncPoint3 => 'CobaltAsyncBuilder 只显示一次加载——之后打开的页面立刻渲染';

  @override
  String get lazyAsyncPoint4 => '失败的构建不会被记住，所以重试会重新构建';

  @override
  String get lazyAsyncStarted => '启动已完成';

  @override
  String get lazyAsyncOpen => '打开搜索';

  @override
  String get lazyAsyncOpenDetail => '第一次进入构建引擎，之后的进入发现它已就绪';

  @override
  String get lazyAsyncSearchTitle => '搜索';

  @override
  String get lazyAsyncBuilding => '正在构建引擎…';

  @override
  String lazyAsyncBuilds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '引擎已构建 $count 次',
      zero: '引擎尚未构建',
    );
    return '$_temp0';
  }

  @override
  String lazyAsyncReady(String instance) {
    return '引擎已就绪 · 实例 $instance';
  }

  @override
  String get propertyTitle => '属性注入';

  @override
  String get propertyTeaches => '构造函数为空的控制器，字段由依赖图填充。';

  @override
  String get propertyPoint1 => '混入类生成在该类旁边，并在构造之后填充字段';

  @override
  String get propertyPoint2 => '字段可以是私有的 —— part 文件位于同一个库中';

  @override
  String get propertyPoint3 => 'late final 会被强制执行，因此二次赋值会抛出异常，而不是悄悄换掉一个依赖';

  @override
  String get propertyPoint4 => '正是这一点消除了五到十四个构造函数参数';

  @override
  String get namedTitle => '命名注入与多重注入';

  @override
  String get namedTeaches => '一个接口背后有多个实现，靠名字区分。';

  @override
  String get namedPoint1 => '@Named 从同一类型的多个注册中挑出一个';

  @override
  String get namedPoint2 => 'getAll 按注册顺序返回该类型的每一个注册';

  @override
  String get namedPoint3 => '同一作用域内重复的键是错误，而不是悄悄地“后者覆盖前者”';

  @override
  String get widgetScopeTitle => '由控件持有的作用域';

  @override
  String get widgetScopeTeaches => '生命周期正好等于一个界面的依赖图。';

  @override
  String get widgetScopePoint1 => 'CobaltScopedStatefulWidget 把注册写进它自己持有的作用域';

  @override
  String get widgetScopePoint2 => '离开界面时，界面构建的一切都会被释放';

  @override
  String get widgetScopePoint3 => 'registerParamFactory 把一个值传入构造过程';

  @override
  String get widgetScopePoint4 => '父依赖图不受影响 —— 这是一个子作用域，而不是一次修改';

  @override
  String get sessionTitle => '会话作用域';

  @override
  String get sessionTeaches => '退出登录就是一次 dispose()，没有别的。';

  @override
  String get sessionPoint1 => '会话构建的一切都随会话作用域一起消失';

  @override
  String get sessionPoint2 => '没有仓储需要实现 reset()，也没有谁去监听会话状态';

  @override
  String get sessionPoint3 => '这正是选择作用域树而非扁平栈的理由';

  @override
  String get scopeTreeTitle => '作用域树';

  @override
  String get scopeTreeTeaches => '实时的层级结构，直接由作用域本身渲染。';

  @override
  String get scopeTreePoint1 => 'CobaltScope.children 是公开的，因此这棵树在运行时可以被检查';

  @override
  String get scopeTreePoint2 => '同时打开两个示例，它们的树互不相干 —— 各有各的根';

  @override
  String get scopeTreePoint3 => '深度和父级就在作用域上，诊断读取的正是它们';

  @override
  String get flowTitle => '导航流程';

  @override
  String get flowTeaches => '生命周期正好等于一个导航流程打开时长的作用域。';

  @override
  String get flowPoint1 => 'CobaltShellRoute —— 进入流程作用域就出现，离开就消失';

  @override
  String get flowPoint2 => '当流程的主体发生变化时，identity 会重建作用域';

  @override
  String get flowPoint3 => '标签页：分支保持存活而非可见，因此切换不会释放任何东西';

  @override
  String get flowPoint4 => '没有任何路由监听器 —— 所有权属于控件树';

  @override
  String get teardownTitle => '拆解';

  @override
  String get teardownTeaches => '释放到底保证了什么 —— 顺序、失败、超时与收养。';

  @override
  String get teardownPoint1 => '按创建顺序后进先出，而不是按声明顺序';

  @override
  String get teardownPoint2 => '抛出异常的 dispose 会被记录；其余的照样执行';

  @override
  String get teardownPoint3 => '挂起的 dispose 会撞上截止时间并被上报，而不是永远等待';

  @override
  String get teardownPoint4 => 'adopt() 把一个并非依赖的对象的生命周期绑定到作用域上';

  @override
  String get codegenTitle => '生成的容器';

  @override
  String get codegenTeaches => '最小的代码生成配置，以及它写出了什么。';

  @override
  String get codegenPoint1 => '给一个类加上 @cobaltInject，lib/cobalt.g.dart 就会出现';

  @override
  String get codegenPoint2 => '输出中是具名的 const 工厂类 —— 从不是闭包';

  @override
  String get codegenPoint3 => '注册顺序由编译期的拓扑排序决定';

  @override
  String get codegenPoint4 => '依赖环会让构建失败，并指出这个环';

  @override
  String get manualTitle => '手写模式';

  @override
  String get manualTeaches => '同样的依赖图，不用代码生成，也不用 Flutter。';

  @override
  String get manualPoint1 => '生成器写出的正是这些，且只用公开 API';

  @override
  String get manualPoint2 => '纯 Dart —— 可运行在命令行、服务器和普通测试中';

  @override
  String get manualPoint3 => 'CobaltScopeBuilder 可以组合，这正是模块的替代物';

  @override
  String get manualPoint4 => '如果代码生成需要这里无法表达的东西，那就是两个共用一个名字的框架';

  @override
  String get eventsTitle => '依赖图事件';

  @override
  String get eventsTeaches => '依赖图报告自身状态，并流向你已经在用的日志库。';

  @override
  String get eventsPoint1 => 'CobaltObserver 事件 —— 作用域入栈、实例构建、释放失败';

  @override
  String get eventsPoint2 => '一行代码即可接上 talker、logging、logger 或任何日志库';

  @override
  String get eventsPoint3 => 'CobaltMultiSink 会把一条记录分发出去；某个接收端失败不会让其余的静音';

  @override
  String get eventsPoint4 => '解析过程刻意不上报 —— 缓存命中是热路径';

  @override
  String get inspectorTitle => '应用内检查器';

  @override
  String get inspectorTeaches => '实时的作用域树、构建了什么以及各自的生命周期，就在应用内的一个界面上。';

  @override
  String get inspectorPoint1 => '这棵树是从活着的作用域走出来的，而不是从事件重建的';

  @override
  String get inspectorPoint2 => '每个注册都带着自己的生命周期，通过 debugKindOf 读出';

  @override
  String get inspectorPoint3 => '点击只展示事实；构建是一个单独的操作，并会说明它的代价';

  @override
  String get inspectorPoint4 => '急切单例出现在树里，却永远不会出现在“已构建”列表中';

  @override
  String get testingTitle => '测试写法';

  @override
  String get testingTeaches => '在测试中替换依赖，以及其中的陷阱。';

  @override
  String get testingPoint1 => '通过压入子作用域并重新注册来替换 —— 是遮蔽，而不是修改';

  @override
  String get testingPoint2 => '在 setUp 中构建依赖图；testWidgets 运行在 fake-async 区域内';

  @override
  String get testingPoint3 => '没有全局容器，因此一个测试不会泄漏到下一个';

  @override
  String get testingPoint4 => '同一作用域内的重复是错误；从子作用域遮蔽才是受支持的做法';

  @override
  String get demoTitle => 'Cobalt · 检查器';

  @override
  String get demoInspect => '检查依赖图';

  @override
  String get demoOpenSession => '打开一个会话作用域';

  @override
  String get demoOpenSessionHint => '一次入栈、一次异步初始化、若干实例';

  @override
  String get demoCloseSession => '关闭会话';

  @override
  String get demoNothingOpen => '没有打开任何东西';

  @override
  String get demoTearsItDown => '会把它拆掉';

  @override
  String get demoThenOpen => '然后从顶栏打开检查器';

  @override
  String get demoThenOpenHint => '作用域树、已构建的实例，以及所有上报内容';

  @override
  String get hostFailed => '这个示例没能启动';

  @override
  String get hostRetry => '重试';
}
