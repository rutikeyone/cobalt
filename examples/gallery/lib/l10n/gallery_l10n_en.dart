// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'gallery_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class GalleryL10nEn extends GalleryL10n {
  GalleryL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Cobalt examples';

  @override
  String get tagline => 'dependency injection · examples';

  @override
  String get lede =>
      'One example per capability. Most open right here; the ones that only print show you their output instead.';

  @override
  String get languageTooltip => 'language';

  @override
  String get allExamples => 'All examples';

  @override
  String get whatItShows => 'What it shows';

  @override
  String get openExample => 'Open example';

  @override
  String get copyCommand => 'Copy command';

  @override
  String get commandCopied => 'Command copied';

  @override
  String get kindScreen => 'screen';

  @override
  String get kindTerminal => 'terminal';

  @override
  String get whereItLives => 'Where it lives';

  @override
  String get consoleOutput => 'Console output';

  @override
  String get testOutput => 'Test output';

  @override
  String get sectionStartup => 'Startup';

  @override
  String get sectionStartupBlurb =>
      'Getting a graph up, and choosing which graph';

  @override
  String get sectionInjection => 'Injection';

  @override
  String get sectionInjectionBlurb =>
      'Getting dependencies into the things that need them';

  @override
  String get sectionScopes => 'Scopes & lifetime';

  @override
  String get sectionScopesBlurb =>
      'When a graph appears, and when it goes away';

  @override
  String get sectionCodegen => 'Code generation';

  @override
  String get sectionCodegenBlurb =>
      'What the generator writes, and the same by hand';

  @override
  String get sectionObservability => 'Observability';

  @override
  String get sectionObservabilityBlurb => 'Watching what the graph does';

  @override
  String get sectionTesting => 'Testing';

  @override
  String get sectionTestingBlurb => 'Swapping dependencies out, and the traps';

  @override
  String get startupTitle => 'Two-phase startup';

  @override
  String get startupTeaches =>
      'Bootstrap steps run before a container exists; async initializers run as a graph.';

  @override
  String get startupPoint1 =>
      'Phase 0 steps are adopted by the root scope and released with it';

  @override
  String get startupPoint2 =>
      'A step that opened something is closed last, after everything built on it';

  @override
  String get startupPoint3 =>
      'Phase 1 awaits @CobaltInit as a graph, so independent branches run together';

  @override
  String get startupPoint4 =>
      'dependsOn decides the order — you never write the sequence yourself';

  @override
  String get environmentsTitle => 'Environments';

  @override
  String get environmentsTeaches =>
      'One interface, a different implementation per build.';

  @override
  String get environmentsPoint1 =>
      '@CobaltEnvironment repeats rather than taking a list — a registration belongs to a set, a start picks one';

  @override
  String get environmentsPoint2 =>
      'Two registrations whose environments overlap fail the build, not the app';

  @override
  String get environmentsPoint3 =>
      'Choosing nothing leaves the split types unregistered, so the miss is loud';

  @override
  String get environmentsPoint4 =>
      'Manual Mode writes the same `if` the generator emits';

  @override
  String get lazyAsyncTitle => 'Lazy async';

  @override
  String get lazyAsyncTeaches =>
      'Something expensive, built by the first screen that asks rather than at startup.';

  @override
  String get lazyAsyncPoint1 =>
      'registerLazyAsyncSingleton, or @CobaltInit(lazy: true), keeps it out of init(), so startup never waits for it';

  @override
  String get lazyAsyncPoint2 =>
      'The first getAsync builds it; every caller at the same time waits for that one build';

  @override
  String get lazyAsyncPoint3 =>
      'CobaltAsyncBuilder shows loading once — a screen opened later renders it at once';

  @override
  String get lazyAsyncPoint4 =>
      'A failed build is not remembered, so retry builds again';

  @override
  String get lazyAsyncStarted => 'startup finished';

  @override
  String get lazyAsyncOpen => 'Open search';

  @override
  String get lazyAsyncOpenDetail =>
      'the first visit builds the engine; later ones find it built';

  @override
  String get lazyAsyncWarmUp => 'Warm up';

  @override
  String get lazyAsyncWarmUpDetail =>
      'scope.warmUp builds it now, so search opens without waiting';

  @override
  String get lazyAsyncSearchTitle => 'Search';

  @override
  String get lazyAsyncBuilding => 'building the engine…';

  @override
  String lazyAsyncBuilds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'engine built $count times',
      one: 'engine built once',
      zero: 'engine not built yet',
    );
    return '$_temp0';
  }

  @override
  String lazyAsyncReady(String instance) {
    return 'engine ready · instance $instance';
  }

  @override
  String get propertyTitle => 'Property injection';

  @override
  String get propertyTeaches =>
      'A controller with an empty constructor and fields filled from the graph.';

  @override
  String get propertyPoint1 =>
      'The mixin is generated beside the class and fills the fields after construction';

  @override
  String get propertyPoint2 =>
      'Fields may be private — the part file is in the same library';

  @override
  String get propertyPoint3 =>
      'late final is enforced, so a second assignment throws instead of quietly swapping a dependency';

  @override
  String get propertyPoint4 =>
      'This is what removes five to fourteen constructor arguments';

  @override
  String get namedTitle => 'Named and multi-injection';

  @override
  String get namedTeaches =>
      'Several implementations behind one interface, told apart by name.';

  @override
  String get namedPoint1 =>
      '@Named picks one registration of a type that has several';

  @override
  String get namedPoint2 =>
      'getAll returns every registration of a type, in registration order';

  @override
  String get namedPoint3 =>
      'A duplicate of the same key in one scope is an error, not a silent last-one-wins';

  @override
  String get decoratorsTitle => 'Decorators';

  @override
  String get decoratorsTeaches =>
      'Wrap what a registration hands out — a cache, a log — without touching its class.';

  @override
  String get decoratorsPoint1 =>
      'scope.decorate, or @CobaltDecorates when the container is generated';

  @override
  String get decoratorsPoint2 =>
      'The first decorator added is innermost, so logging here sees cached answers';

  @override
  String get decoratorsPoint3 =>
      'A retained registration is decorated once and shared; the scope closes only the inner instance';

  @override
  String get decoratorsPoint4 =>
      'An override is decorated like the registration it replaced';

  @override
  String get decoratorsChain => 'wrapped, innermost first';

  @override
  String decoratorsAsk(String city) {
    return 'Forecast for $city';
  }

  @override
  String decoratorsStationCalls(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'reached $count times',
      one: 'reached once',
      zero: 'not reached yet',
    );
    return '$_temp0';
  }

  @override
  String get widgetScopeTitle => 'Widget-owned scope';

  @override
  String get widgetScopeTeaches =>
      'A graph that lives exactly as long as one screen.';

  @override
  String get widgetScopePoint1 =>
      'CobaltScopedStatefulWidget registers into a scope it owns';

  @override
  String get widgetScopePoint2 =>
      'Leaving the screen disposes everything the screen built';

  @override
  String get widgetScopePoint3 =>
      'registerParamFactory passes a value into construction';

  @override
  String get widgetScopePoint4 =>
      'The parent graph stays untouched — this is a child, not a mutation';

  @override
  String get sessionTitle => 'Session scope';

  @override
  String get sessionTeaches => 'Signing out is one dispose() and nothing else.';

  @override
  String get sessionPoint1 =>
      'Everything the session built goes with the session scope';

  @override
  String get sessionPoint2 =>
      'No repository implements reset(), and nothing listens to the session';

  @override
  String get sessionPoint3 =>
      'This is the argument for a tree of scopes rather than a flat stack';

  @override
  String get scopeTreeTitle => 'Scope tree';

  @override
  String get scopeTreeTeaches =>
      'The live hierarchy, rendered from the scopes themselves.';

  @override
  String get scopeTreePoint1 =>
      'CobaltScope.children is public, so the tree is inspectable at runtime';

  @override
  String get scopeTreePoint2 =>
      'Open two examples and their trees are unrelated — each has its own root';

  @override
  String get scopeTreePoint3 =>
      'Depth and parent are on the scope, which is what diagnostics read';

  @override
  String get flowTitle => 'Navigation flows';

  @override
  String get flowTeaches =>
      'A scope that lives exactly as long as a navigation flow is open.';

  @override
  String get flowPoint1 =>
      'CobaltShellRoute — enter the flow and the scope appears; leave and it is gone';

  @override
  String get flowPoint2 =>
      'identity rebuilds the scope when the flow’s subject changes';

  @override
  String get flowPoint3 =>
      'Tabs: a branch is kept alive, not visible, so switching disposes nothing';

  @override
  String get flowPoint4 =>
      'No router listener anywhere — ownership belongs to the widget tree';

  @override
  String get teardownTitle => 'Teardown';

  @override
  String get teardownTeaches =>
      'What disposal actually guarantees — order, failures, timeouts, adoption.';

  @override
  String get teardownPoint1 =>
      'LIFO by creation order, not by the order things were declared';

  @override
  String get teardownPoint2 =>
      'A dispose that throws is recorded; everything else still runs';

  @override
  String get teardownPoint3 =>
      'A dispose that hangs hits the deadline and is reported, not awaited forever';

  @override
  String get teardownPoint4 =>
      'adopt() ties a non-dependency’s life to the scope';

  @override
  String get codegenTitle => 'Generated container';

  @override
  String get codegenTeaches =>
      'The smallest generated setup there is, and what it writes.';

  @override
  String get codegenPoint1 =>
      'Put @cobaltInject on a class and lib/cobalt.g.dart appears';

  @override
  String get codegenPoint2 =>
      'Named const factory classes in the output — never closures';

  @override
  String get codegenPoint3 =>
      'Registrations ordered by a compile-time topological sort';

  @override
  String get codegenPoint4 =>
      'A dependency cycle fails the build naming the cycle';

  @override
  String get manualTitle => 'Manual mode';

  @override
  String get manualTeaches =>
      'The same graph with no generation and no Flutter.';

  @override
  String get manualPoint1 =>
      'The generator writes exactly this, using only the public API';

  @override
  String get manualPoint2 =>
      'Pure Dart — runs in a CLI, on a server, in a plain test';

  @override
  String get manualPoint3 =>
      'CobaltScopeBuilder composes; that is what replaces modules';

  @override
  String get manualPoint4 =>
      'If generation ever needs something this cannot express, they are two frameworks sharing a name';

  @override
  String get eventsTitle => 'Graph events';

  @override
  String get eventsTeaches =>
      'The graph reporting on itself, streamed into a logger you already use.';

  @override
  String get eventsPoint1 =>
      'CobaltObserver events — scopes pushed, instances built, teardown failing';

  @override
  String get eventsPoint2 =>
      'One line to adapt talker, logging, logger, or any logger at all';

  @override
  String get eventsPoint3 =>
      'CobaltMultiSink fans a record out; a failing sink does not silence the rest';

  @override
  String get eventsPoint4 =>
      'Resolution is deliberately not reported — a cache hit is the hot path';

  @override
  String get inspectorTitle => 'In-app inspector';

  @override
  String get inspectorTeaches =>
      'The live tree, what was built and with what lifetime, on a screen in the app.';

  @override
  String get inspectorPoint1 =>
      'The tree is walked from the live scopes, not rebuilt from events';

  @override
  String get inspectorPoint2 =>
      'Every registration carries its lifetime, read with debugKindOf';

  @override
  String get inspectorPoint3 =>
      'Tapping shows facts; building is a separate action that says its cost';

  @override
  String get inspectorPoint4 =>
      'An eager singleton shows in the tree and never in the built list';

  @override
  String get testingTitle => 'Testing patterns';

  @override
  String get testingTeaches =>
      'Overriding dependencies in a test, and the traps.';

  @override
  String get testingPoint1 =>
      'Override by pushing a child scope and registering again — shadowing, not mutation';

  @override
  String get testingPoint2 =>
      'Build the graph in setUp; testWidgets runs inside a fake-async zone';

  @override
  String get testingPoint3 =>
      'No global container, so one test cannot leak into the next';

  @override
  String get testingPoint4 =>
      'A duplicate in one scope is an error; shadowing from a child is the supported way';

  @override
  String get demoTitle => 'Cobalt · inspector';

  @override
  String get demoInspect => 'inspect the graph';

  @override
  String get demoOpenSession => 'Open a session scope';

  @override
  String get demoOpenSessionHint => 'a push, an async init, some instances';

  @override
  String get demoCloseSession => 'Close the session';

  @override
  String get demoNothingOpen => 'nothing open';

  @override
  String get demoTearsItDown => 'tears it down';

  @override
  String get demoThenOpen => 'Then open the inspector from the app bar';

  @override
  String get demoThenOpenHint =>
      'the tree, what was built, and everything reported';

  @override
  String get hostFailed => 'This example could not start';

  @override
  String get hostRetry => 'Try again';
}
