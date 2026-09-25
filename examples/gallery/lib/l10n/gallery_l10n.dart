import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'gallery_l10n_en.dart';
import 'gallery_l10n_ru.dart';
import 'gallery_l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of GalleryL10n
/// returned by `GalleryL10n.of(context)`.
///
/// Applications need to include `GalleryL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/gallery_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: GalleryL10n.localizationsDelegates,
///   supportedLocales: GalleryL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the GalleryL10n.supportedLocales
/// property.
abstract class GalleryL10n {
  GalleryL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static GalleryL10n of(BuildContext context) {
    return Localizations.of<GalleryL10n>(context, GalleryL10n)!;
  }

  static const LocalizationsDelegate<GalleryL10n> delegate =
      _GalleryL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// Title of the gallery application.
  ///
  /// In en, this message translates to:
  /// **'Cobalt examples'**
  String get appTitle;

  /// Subtitle under the Cobalt wordmark.
  ///
  /// In en, this message translates to:
  /// **'dependency injection · examples'**
  String get tagline;

  /// Introductory paragraph on the hub screen.
  ///
  /// In en, this message translates to:
  /// **'One example per capability. Most open right here; the ones that only print show you their output instead.'**
  String get lede;

  /// Tooltip of the language switcher.
  ///
  /// In en, this message translates to:
  /// **'language'**
  String get languageTooltip;

  /// Back-link title on a detail screen.
  ///
  /// In en, this message translates to:
  /// **'All examples'**
  String get allExamples;

  /// Heading above the bullet points of an example.
  ///
  /// In en, this message translates to:
  /// **'What it shows'**
  String get whatItShows;

  /// Button that mounts an example.
  ///
  /// In en, this message translates to:
  /// **'Open example'**
  String get openExample;

  /// Button for an example that only prints; copies how to run it.
  ///
  /// In en, this message translates to:
  /// **'Copy command'**
  String get copyCommand;

  /// Confirmation after copying a command.
  ///
  /// In en, this message translates to:
  /// **'Command copied'**
  String get commandCopied;

  /// Badge on an example you can open.
  ///
  /// In en, this message translates to:
  /// **'screen'**
  String get kindScreen;

  /// Badge on an example that only prints.
  ///
  /// In en, this message translates to:
  /// **'terminal'**
  String get kindTerminal;

  /// Label above the path to an example's source.
  ///
  /// In en, this message translates to:
  /// **'Where it lives'**
  String get whereItLives;

  /// Label above the command that runs an example that prints.
  ///
  /// In en, this message translates to:
  /// **'Console output'**
  String get consoleOutput;

  /// Label above the command that runs an example's tests.
  ///
  /// In en, this message translates to:
  /// **'Test output'**
  String get testOutput;

  /// No description provided for @sectionStartup.
  ///
  /// In en, this message translates to:
  /// **'Startup'**
  String get sectionStartup;

  /// No description provided for @sectionStartupBlurb.
  ///
  /// In en, this message translates to:
  /// **'Getting a graph up, and choosing which graph'**
  String get sectionStartupBlurb;

  /// No description provided for @sectionInjection.
  ///
  /// In en, this message translates to:
  /// **'Injection'**
  String get sectionInjection;

  /// No description provided for @sectionInjectionBlurb.
  ///
  /// In en, this message translates to:
  /// **'Getting dependencies into the things that need them'**
  String get sectionInjectionBlurb;

  /// No description provided for @sectionScopes.
  ///
  /// In en, this message translates to:
  /// **'Scopes & lifetime'**
  String get sectionScopes;

  /// No description provided for @sectionScopesBlurb.
  ///
  /// In en, this message translates to:
  /// **'When a graph appears, and when it goes away'**
  String get sectionScopesBlurb;

  /// No description provided for @sectionCodegen.
  ///
  /// In en, this message translates to:
  /// **'Code generation'**
  String get sectionCodegen;

  /// No description provided for @sectionCodegenBlurb.
  ///
  /// In en, this message translates to:
  /// **'What the generator writes, and the same by hand'**
  String get sectionCodegenBlurb;

  /// No description provided for @sectionObservability.
  ///
  /// In en, this message translates to:
  /// **'Observability'**
  String get sectionObservability;

  /// No description provided for @sectionObservabilityBlurb.
  ///
  /// In en, this message translates to:
  /// **'Watching what the graph does'**
  String get sectionObservabilityBlurb;

  /// No description provided for @sectionTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get sectionTesting;

  /// No description provided for @sectionTestingBlurb.
  ///
  /// In en, this message translates to:
  /// **'Swapping dependencies out, and the traps'**
  String get sectionTestingBlurb;

  /// Name of the "Two-phase startup" example.
  ///
  /// In en, this message translates to:
  /// **'Two-phase startup'**
  String get startupTitle;

  /// One line: what "Two-phase startup" exists to show.
  ///
  /// In en, this message translates to:
  /// **'Bootstrap steps run before a container exists; async initializers run as a graph.'**
  String get startupTeaches;

  /// No description provided for @startupPoint1.
  ///
  /// In en, this message translates to:
  /// **'Phase 0 steps are adopted by the root scope and released with it'**
  String get startupPoint1;

  /// No description provided for @startupPoint2.
  ///
  /// In en, this message translates to:
  /// **'A step that opened something is closed last, after everything built on it'**
  String get startupPoint2;

  /// No description provided for @startupPoint3.
  ///
  /// In en, this message translates to:
  /// **'Phase 1 awaits @CobaltInit as a graph, so independent branches run together'**
  String get startupPoint3;

  /// No description provided for @startupPoint4.
  ///
  /// In en, this message translates to:
  /// **'dependsOn decides the order — you never write the sequence yourself'**
  String get startupPoint4;

  /// Name of the "Environments" example.
  ///
  /// In en, this message translates to:
  /// **'Environments'**
  String get environmentsTitle;

  /// One line: what "Environments" exists to show.
  ///
  /// In en, this message translates to:
  /// **'One interface, a different implementation per build.'**
  String get environmentsTeaches;

  /// No description provided for @environmentsPoint1.
  ///
  /// In en, this message translates to:
  /// **'@CobaltEnvironment repeats rather than taking a list — a registration belongs to a set, a start picks one'**
  String get environmentsPoint1;

  /// No description provided for @environmentsPoint2.
  ///
  /// In en, this message translates to:
  /// **'Two registrations whose environments overlap fail the build, not the app'**
  String get environmentsPoint2;

  /// No description provided for @environmentsPoint3.
  ///
  /// In en, this message translates to:
  /// **'Choosing nothing leaves the split types unregistered, so the miss is loud'**
  String get environmentsPoint3;

  /// No description provided for @environmentsPoint4.
  ///
  /// In en, this message translates to:
  /// **'Manual Mode writes the same `if` the generator emits'**
  String get environmentsPoint4;

  /// Name of the "Lazy async" example.
  ///
  /// In en, this message translates to:
  /// **'Lazy async'**
  String get lazyAsyncTitle;

  /// One line: what "Lazy async" exists to show.
  ///
  /// In en, this message translates to:
  /// **'Something expensive, built by the first screen that asks rather than at startup.'**
  String get lazyAsyncTeaches;

  /// No description provided for @lazyAsyncPoint1.
  ///
  /// In en, this message translates to:
  /// **'registerLazyAsyncSingleton, or @CobaltInit(lazy: true), keeps it out of init(), so startup never waits for it'**
  String get lazyAsyncPoint1;

  /// No description provided for @lazyAsyncPoint2.
  ///
  /// In en, this message translates to:
  /// **'The first getAsync builds it; every caller at the same time waits for that one build'**
  String get lazyAsyncPoint2;

  /// No description provided for @lazyAsyncPoint3.
  ///
  /// In en, this message translates to:
  /// **'CobaltAsyncBuilder shows loading once — a screen opened later renders it at once'**
  String get lazyAsyncPoint3;

  /// No description provided for @lazyAsyncPoint4.
  ///
  /// In en, this message translates to:
  /// **'A failed build is not remembered, so retry builds again'**
  String get lazyAsyncPoint4;

  /// Shown on the lazy async screen once the graph is up.
  ///
  /// In en, this message translates to:
  /// **'startup finished'**
  String get lazyAsyncStarted;

  /// Opens the screen that needs the lazy engine.
  ///
  /// In en, this message translates to:
  /// **'Open search'**
  String get lazyAsyncOpen;

  /// What opening the search screen does.
  ///
  /// In en, this message translates to:
  /// **'the first visit builds the engine; later ones find it built'**
  String get lazyAsyncOpenDetail;

  /// Starts building the lazy engine before the search screen is opened.
  ///
  /// In en, this message translates to:
  /// **'Warm up'**
  String get lazyAsyncWarmUp;

  /// What warming up does.
  ///
  /// In en, this message translates to:
  /// **'scope.warmUp builds it now, so search opens without waiting'**
  String get lazyAsyncWarmUpDetail;

  /// Title of the screen that waits for the lazy engine.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get lazyAsyncSearchTitle;

  /// Shown while the lazy engine is being built.
  ///
  /// In en, this message translates to:
  /// **'building the engine…'**
  String get lazyAsyncBuilding;

  /// How many times the lazy engine has been built this visit.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{engine not built yet} =1{engine built once} other{engine built {count} times}}'**
  String lazyAsyncBuilds(int count);

  /// The engine was resolved; the instance shows a second visit gets the same one.
  ///
  /// In en, this message translates to:
  /// **'engine ready · instance {instance}'**
  String lazyAsyncReady(String instance);

  /// Name of the "Property injection" example.
  ///
  /// In en, this message translates to:
  /// **'Property injection'**
  String get propertyTitle;

  /// One line: what "Property injection" exists to show.
  ///
  /// In en, this message translates to:
  /// **'A controller with an empty constructor and fields filled from the graph.'**
  String get propertyTeaches;

  /// No description provided for @propertyPoint1.
  ///
  /// In en, this message translates to:
  /// **'The mixin is generated beside the class and fills the fields after construction'**
  String get propertyPoint1;

  /// No description provided for @propertyPoint2.
  ///
  /// In en, this message translates to:
  /// **'Fields may be private — the part file is in the same library'**
  String get propertyPoint2;

  /// No description provided for @propertyPoint3.
  ///
  /// In en, this message translates to:
  /// **'late final is enforced, so a second assignment throws instead of quietly swapping a dependency'**
  String get propertyPoint3;

  /// No description provided for @propertyPoint4.
  ///
  /// In en, this message translates to:
  /// **'This is what removes five to fourteen constructor arguments'**
  String get propertyPoint4;

  /// Name of the "Named and multi-injection" example.
  ///
  /// In en, this message translates to:
  /// **'Named and multi-injection'**
  String get namedTitle;

  /// One line: what "Named and multi-injection" exists to show.
  ///
  /// In en, this message translates to:
  /// **'Several implementations behind one interface, told apart by name.'**
  String get namedTeaches;

  /// No description provided for @namedPoint1.
  ///
  /// In en, this message translates to:
  /// **'@Named picks one registration of a type that has several'**
  String get namedPoint1;

  /// No description provided for @namedPoint2.
  ///
  /// In en, this message translates to:
  /// **'getAll returns every registration of a type, in registration order'**
  String get namedPoint2;

  /// No description provided for @namedPoint3.
  ///
  /// In en, this message translates to:
  /// **'A duplicate of the same key in one scope is an error, not a silent last-one-wins'**
  String get namedPoint3;

  /// Name of the "Widget-owned scope" example.
  ///
  /// In en, this message translates to:
  /// **'Widget-owned scope'**
  String get widgetScopeTitle;

  /// One line: what "Widget-owned scope" exists to show.
  ///
  /// In en, this message translates to:
  /// **'A graph that lives exactly as long as one screen.'**
  String get widgetScopeTeaches;

  /// No description provided for @widgetScopePoint1.
  ///
  /// In en, this message translates to:
  /// **'CobaltScopedStatefulWidget registers into a scope it owns'**
  String get widgetScopePoint1;

  /// No description provided for @widgetScopePoint2.
  ///
  /// In en, this message translates to:
  /// **'Leaving the screen disposes everything the screen built'**
  String get widgetScopePoint2;

  /// No description provided for @widgetScopePoint3.
  ///
  /// In en, this message translates to:
  /// **'registerParamFactory passes a value into construction'**
  String get widgetScopePoint3;

  /// No description provided for @widgetScopePoint4.
  ///
  /// In en, this message translates to:
  /// **'The parent graph stays untouched — this is a child, not a mutation'**
  String get widgetScopePoint4;

  /// Name of the "Session scope" example.
  ///
  /// In en, this message translates to:
  /// **'Session scope'**
  String get sessionTitle;

  /// One line: what "Session scope" exists to show.
  ///
  /// In en, this message translates to:
  /// **'Signing out is one dispose() and nothing else.'**
  String get sessionTeaches;

  /// No description provided for @sessionPoint1.
  ///
  /// In en, this message translates to:
  /// **'Everything the session built goes with the session scope'**
  String get sessionPoint1;

  /// No description provided for @sessionPoint2.
  ///
  /// In en, this message translates to:
  /// **'No repository implements reset(), and nothing listens to the session'**
  String get sessionPoint2;

  /// No description provided for @sessionPoint3.
  ///
  /// In en, this message translates to:
  /// **'This is the argument for a tree of scopes rather than a flat stack'**
  String get sessionPoint3;

  /// Name of the "Scope tree" example.
  ///
  /// In en, this message translates to:
  /// **'Scope tree'**
  String get scopeTreeTitle;

  /// One line: what "Scope tree" exists to show.
  ///
  /// In en, this message translates to:
  /// **'The live hierarchy, rendered from the scopes themselves.'**
  String get scopeTreeTeaches;

  /// No description provided for @scopeTreePoint1.
  ///
  /// In en, this message translates to:
  /// **'CobaltScope.children is public, so the tree is inspectable at runtime'**
  String get scopeTreePoint1;

  /// No description provided for @scopeTreePoint2.
  ///
  /// In en, this message translates to:
  /// **'Open two examples and their trees are unrelated — each has its own root'**
  String get scopeTreePoint2;

  /// No description provided for @scopeTreePoint3.
  ///
  /// In en, this message translates to:
  /// **'Depth and parent are on the scope, which is what diagnostics read'**
  String get scopeTreePoint3;

  /// Name of the "Navigation flows" example.
  ///
  /// In en, this message translates to:
  /// **'Navigation flows'**
  String get flowTitle;

  /// One line: what "Navigation flows" exists to show.
  ///
  /// In en, this message translates to:
  /// **'A scope that lives exactly as long as a navigation flow is open.'**
  String get flowTeaches;

  /// No description provided for @flowPoint1.
  ///
  /// In en, this message translates to:
  /// **'CobaltShellRoute — enter the flow and the scope appears; leave and it is gone'**
  String get flowPoint1;

  /// No description provided for @flowPoint2.
  ///
  /// In en, this message translates to:
  /// **'identity rebuilds the scope when the flow’s subject changes'**
  String get flowPoint2;

  /// No description provided for @flowPoint3.
  ///
  /// In en, this message translates to:
  /// **'Tabs: a branch is kept alive, not visible, so switching disposes nothing'**
  String get flowPoint3;

  /// No description provided for @flowPoint4.
  ///
  /// In en, this message translates to:
  /// **'No router listener anywhere — ownership belongs to the widget tree'**
  String get flowPoint4;

  /// Name of the "Teardown" example.
  ///
  /// In en, this message translates to:
  /// **'Teardown'**
  String get teardownTitle;

  /// One line: what "Teardown" exists to show.
  ///
  /// In en, this message translates to:
  /// **'What disposal actually guarantees — order, failures, timeouts, adoption.'**
  String get teardownTeaches;

  /// No description provided for @teardownPoint1.
  ///
  /// In en, this message translates to:
  /// **'LIFO by creation order, not by the order things were declared'**
  String get teardownPoint1;

  /// No description provided for @teardownPoint2.
  ///
  /// In en, this message translates to:
  /// **'A dispose that throws is recorded; everything else still runs'**
  String get teardownPoint2;

  /// No description provided for @teardownPoint3.
  ///
  /// In en, this message translates to:
  /// **'A dispose that hangs hits the deadline and is reported, not awaited forever'**
  String get teardownPoint3;

  /// No description provided for @teardownPoint4.
  ///
  /// In en, this message translates to:
  /// **'adopt() ties a non-dependency’s life to the scope'**
  String get teardownPoint4;

  /// Name of the "Generated container" example.
  ///
  /// In en, this message translates to:
  /// **'Generated container'**
  String get codegenTitle;

  /// One line: what "Generated container" exists to show.
  ///
  /// In en, this message translates to:
  /// **'The smallest generated setup there is, and what it writes.'**
  String get codegenTeaches;

  /// No description provided for @codegenPoint1.
  ///
  /// In en, this message translates to:
  /// **'Put @cobaltInject on a class and lib/cobalt.g.dart appears'**
  String get codegenPoint1;

  /// No description provided for @codegenPoint2.
  ///
  /// In en, this message translates to:
  /// **'Named const factory classes in the output — never closures'**
  String get codegenPoint2;

  /// No description provided for @codegenPoint3.
  ///
  /// In en, this message translates to:
  /// **'Registrations ordered by a compile-time topological sort'**
  String get codegenPoint3;

  /// No description provided for @codegenPoint4.
  ///
  /// In en, this message translates to:
  /// **'A dependency cycle fails the build naming the cycle'**
  String get codegenPoint4;

  /// Name of the "Manual mode" example.
  ///
  /// In en, this message translates to:
  /// **'Manual mode'**
  String get manualTitle;

  /// One line: what "Manual mode" exists to show.
  ///
  /// In en, this message translates to:
  /// **'The same graph with no generation and no Flutter.'**
  String get manualTeaches;

  /// No description provided for @manualPoint1.
  ///
  /// In en, this message translates to:
  /// **'The generator writes exactly this, using only the public API'**
  String get manualPoint1;

  /// No description provided for @manualPoint2.
  ///
  /// In en, this message translates to:
  /// **'Pure Dart — runs in a CLI, on a server, in a plain test'**
  String get manualPoint2;

  /// No description provided for @manualPoint3.
  ///
  /// In en, this message translates to:
  /// **'CobaltScopeBuilder composes; that is what replaces modules'**
  String get manualPoint3;

  /// No description provided for @manualPoint4.
  ///
  /// In en, this message translates to:
  /// **'If generation ever needs something this cannot express, they are two frameworks sharing a name'**
  String get manualPoint4;

  /// Name of the "Graph events" example.
  ///
  /// In en, this message translates to:
  /// **'Graph events'**
  String get eventsTitle;

  /// One line: what "Graph events" exists to show.
  ///
  /// In en, this message translates to:
  /// **'The graph reporting on itself, streamed into a logger you already use.'**
  String get eventsTeaches;

  /// No description provided for @eventsPoint1.
  ///
  /// In en, this message translates to:
  /// **'CobaltObserver events — scopes pushed, instances built, teardown failing'**
  String get eventsPoint1;

  /// No description provided for @eventsPoint2.
  ///
  /// In en, this message translates to:
  /// **'One line to adapt talker, logging, logger, or any logger at all'**
  String get eventsPoint2;

  /// No description provided for @eventsPoint3.
  ///
  /// In en, this message translates to:
  /// **'CobaltMultiSink fans a record out; a failing sink does not silence the rest'**
  String get eventsPoint3;

  /// No description provided for @eventsPoint4.
  ///
  /// In en, this message translates to:
  /// **'Resolution is deliberately not reported — a cache hit is the hot path'**
  String get eventsPoint4;

  /// Name of the "In-app inspector" example.
  ///
  /// In en, this message translates to:
  /// **'In-app inspector'**
  String get inspectorTitle;

  /// One line: what "In-app inspector" exists to show.
  ///
  /// In en, this message translates to:
  /// **'The live tree, what was built and with what lifetime, on a screen in the app.'**
  String get inspectorTeaches;

  /// No description provided for @inspectorPoint1.
  ///
  /// In en, this message translates to:
  /// **'The tree is walked from the live scopes, not rebuilt from events'**
  String get inspectorPoint1;

  /// No description provided for @inspectorPoint2.
  ///
  /// In en, this message translates to:
  /// **'Every registration carries its lifetime, read with debugKindOf'**
  String get inspectorPoint2;

  /// No description provided for @inspectorPoint3.
  ///
  /// In en, this message translates to:
  /// **'Tapping shows facts; building is a separate action that says its cost'**
  String get inspectorPoint3;

  /// No description provided for @inspectorPoint4.
  ///
  /// In en, this message translates to:
  /// **'An eager singleton shows in the tree and never in the built list'**
  String get inspectorPoint4;

  /// Name of the "Testing patterns" example.
  ///
  /// In en, this message translates to:
  /// **'Testing patterns'**
  String get testingTitle;

  /// One line: what "Testing patterns" exists to show.
  ///
  /// In en, this message translates to:
  /// **'Overriding dependencies in a test, and the traps.'**
  String get testingTeaches;

  /// No description provided for @testingPoint1.
  ///
  /// In en, this message translates to:
  /// **'Override by pushing a child scope and registering again — shadowing, not mutation'**
  String get testingPoint1;

  /// No description provided for @testingPoint2.
  ///
  /// In en, this message translates to:
  /// **'Build the graph in setUp; testWidgets runs inside a fake-async zone'**
  String get testingPoint2;

  /// No description provided for @testingPoint3.
  ///
  /// In en, this message translates to:
  /// **'No global container, so one test cannot leak into the next'**
  String get testingPoint3;

  /// No description provided for @testingPoint4.
  ///
  /// In en, this message translates to:
  /// **'A duplicate in one scope is an error; shadowing from a child is the supported way'**
  String get testingPoint4;

  /// App bar of the screen the inspector example gives you to poke at.
  ///
  /// In en, this message translates to:
  /// **'Cobalt · inspector'**
  String get demoTitle;

  /// No description provided for @demoInspect.
  ///
  /// In en, this message translates to:
  /// **'inspect the graph'**
  String get demoInspect;

  /// No description provided for @demoOpenSession.
  ///
  /// In en, this message translates to:
  /// **'Open a session scope'**
  String get demoOpenSession;

  /// No description provided for @demoOpenSessionHint.
  ///
  /// In en, this message translates to:
  /// **'a push, an async init, some instances'**
  String get demoOpenSessionHint;

  /// No description provided for @demoCloseSession.
  ///
  /// In en, this message translates to:
  /// **'Close the session'**
  String get demoCloseSession;

  /// No description provided for @demoNothingOpen.
  ///
  /// In en, this message translates to:
  /// **'nothing open'**
  String get demoNothingOpen;

  /// No description provided for @demoTearsItDown.
  ///
  /// In en, this message translates to:
  /// **'tears it down'**
  String get demoTearsItDown;

  /// No description provided for @demoThenOpen.
  ///
  /// In en, this message translates to:
  /// **'Then open the inspector from the app bar'**
  String get demoThenOpen;

  /// No description provided for @demoThenOpenHint.
  ///
  /// In en, this message translates to:
  /// **'the tree, what was built, and everything reported'**
  String get demoThenOpenHint;

  /// Shown when an example fails to build its graph.
  ///
  /// In en, this message translates to:
  /// **'This example could not start'**
  String get hostFailed;

  /// Button that tries to build the example graph again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get hostRetry;
}

class _GalleryL10nDelegate extends LocalizationsDelegate<GalleryL10n> {
  const _GalleryL10nDelegate();

  @override
  Future<GalleryL10n> load(Locale locale) {
    return SynchronousFuture<GalleryL10n>(lookupGalleryL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_GalleryL10nDelegate old) => false;
}

GalleryL10n lookupGalleryL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return GalleryL10nEn();
    case 'ru':
      return GalleryL10nRu();
    case 'zh':
      return GalleryL10nZh();
  }

  throw FlutterError(
    'GalleryL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
