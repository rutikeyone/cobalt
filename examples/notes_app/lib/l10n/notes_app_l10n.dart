import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'notes_app_l10n_en.dart';
import 'notes_app_l10n_ko.dart';
import 'notes_app_l10n_ru.dart';
import 'notes_app_l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of NotesL10n
/// returned by `NotesL10n.of(context)`.
///
/// Applications need to include `NotesL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/notes_app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: NotesL10n.localizationsDelegates,
///   supportedLocales: NotesL10n.supportedLocales,
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
/// be consistent with the languages listed in the NotesL10n.supportedLocales
/// property.
abstract class NotesL10n {
  NotesL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static NotesL10n of(BuildContext context) {
    return Localizations.of<NotesL10n>(context, NotesL10n)!;
  }

  static const LocalizationsDelegate<NotesL10n> delegate = _NotesL10nDelegate();

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
    Locale('ko'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// Title of the startup screen.
  ///
  /// In en, this message translates to:
  /// **'Two-phase startup'**
  String get twoPhaseStartup;

  /// Action that rebuilds the whole graph.
  ///
  /// In en, this message translates to:
  /// **'dispose the app scope and start a new one'**
  String get restartGraph;

  /// Heading above the bootstrap steps.
  ///
  /// In en, this message translates to:
  /// **'Phase 0 — @CobaltBootstrap'**
  String get phaseZero;

  /// Who owns the bootstrap steps.
  ///
  /// In en, this message translates to:
  /// **'adopted by scope \"{scope}\", released when it is disposed'**
  String phaseZeroNote(String scope);

  /// Heading above the async initializers.
  ///
  /// In en, this message translates to:
  /// **'Phase 1 — @CobaltInit'**
  String get phaseOne;

  /// Whether the database finished opening.
  ///
  /// In en, this message translates to:
  /// **'database open'**
  String get databaseOpen;

  /// Whether the index finished building.
  ///
  /// In en, this message translates to:
  /// **'search index built'**
  String get searchIndexBuilt;

  /// Whether telemetry finished starting.
  ///
  /// In en, this message translates to:
  /// **'telemetry started'**
  String get telemetryStarted;

  /// One initializer and whether it is done. The value is a boolean literal, so it reads the same in every language.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String statusLine(String label, String value);

  /// The endpoint a bootstrap step loaded.
  ///
  /// In en, this message translates to:
  /// **'api: {url}'**
  String apiLine(String url);

  /// Title of the session screen.
  ///
  /// In en, this message translates to:
  /// **'Session scope'**
  String get sessionScope;

  /// Who is signed in.
  ///
  /// In en, this message translates to:
  /// **'signed in as {name}'**
  String signedInAs(String name);

  /// Shown when there is no session.
  ///
  /// In en, this message translates to:
  /// **'signed out'**
  String get signedOut;

  /// Which scope the screen is looking at.
  ///
  /// In en, this message translates to:
  /// **'scope: {name}'**
  String scopeLine(String name);

  /// Stands in for a scope that does not exist yet.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get noScope;

  /// Action that pushes the session scope.
  ///
  /// In en, this message translates to:
  /// **'sign in'**
  String get signIn;

  /// Action that disposes it.
  ///
  /// In en, this message translates to:
  /// **'sign out'**
  String get signOut;

  /// Action that writes to the session's log.
  ///
  /// In en, this message translates to:
  /// **'record activity'**
  String get recordActivity;

  /// How much the session has recorded.
  ///
  /// In en, this message translates to:
  /// **'activity: {count}'**
  String activityCount(int count);

  /// Why a session scope replaces manual clean-up.
  ///
  /// In en, this message translates to:
  /// **'Signing out disposes the session scope. Everything built inside it goes with it — no reset() on any repository, no session listener anywhere.'**
  String get sessionExplained;

  /// Title of the notes screen.
  ///
  /// In en, this message translates to:
  /// **'Property injection'**
  String get propertyInjection;

  /// Label of the search field.
  ///
  /// In en, this message translates to:
  /// **'search'**
  String get search;

  /// How many notes are listed.
  ///
  /// In en, this message translates to:
  /// **'count: {count}'**
  String noteCount(int count);

  /// Title given to a note the button creates.
  ///
  /// In en, this message translates to:
  /// **'note {number}'**
  String newNote(int number);

  /// Title of the note detail screen.
  ///
  /// In en, this message translates to:
  /// **'Widget-owned scope'**
  String get widgetOwnedScope;

  /// Label of the draft field.
  ///
  /// In en, this message translates to:
  /// **'draft'**
  String get draft;

  /// Stands in for a draft with nothing typed in it.
  ///
  /// In en, this message translates to:
  /// **'untitled'**
  String get untitled;

  /// What owning a scope buys the screen.
  ///
  /// In en, this message translates to:
  /// **'This screen declares its own scope. Leaving it disposes the scope — nothing else has to remember to.'**
  String get widgetScopeExplained;

  /// Title of the diagnostics screen.
  ///
  /// In en, this message translates to:
  /// **'Scope tree'**
  String get scopeTree;

  /// Title of the formatters screen.
  ///
  /// In en, this message translates to:
  /// **'Named and multi-injection'**
  String get namedAndMulti;

  /// How many implementations getAll found.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 registration} other{{count} registrations}}'**
  String registrationCount(int count);

  /// The note title every formatter is shown formatting.
  ///
  /// In en, this message translates to:
  /// **'shopping list'**
  String get sampleNote;

  /// Title of the environments screen.
  ///
  /// In en, this message translates to:
  /// **'Environments'**
  String get environments;

  /// Which build the graph was started for.
  ///
  /// In en, this message translates to:
  /// **'active environment'**
  String get activeEnvironment;

  /// Which implementation answered, and where it goes. The implementation is a type name and does not translate.
  ///
  /// In en, this message translates to:
  /// **'{implementation} → {detail}'**
  String apiClientLine(String implementation, String detail);

  /// Where a fake implementation goes, which is nowhere.
  ///
  /// In en, this message translates to:
  /// **'no network'**
  String get noNetwork;

  /// Shown when the chosen environment leaves the type absent.
  ///
  /// In en, this message translates to:
  /// **'nothing registered — no implementation claims \"{environment}\"'**
  String nothingRegistered(String environment);

  /// A bootstrap step restricted to some environments.
  ///
  /// In en, this message translates to:
  /// **'report-crashes bootstrap step'**
  String get crashReportingStep;

  /// The step was part of this build.
  ///
  /// In en, this message translates to:
  /// **'ran'**
  String get stepRan;

  /// The step was not.
  ///
  /// In en, this message translates to:
  /// **'skipped in this environment'**
  String get stepSkipped;

  /// Why a missing environment fails loudly.
  ///
  /// In en, this message translates to:
  /// **'Both implementations are annotated with the same exposeAs. Only the one naming this environment is registered, so nothing downstream knows which it got. Pick an environment nobody claims and the type is simply absent — get<ApiClient>() would throw rather than hand back the wrong class.'**
  String get environmentsExplained;
}

class _NotesL10nDelegate extends LocalizationsDelegate<NotesL10n> {
  const _NotesL10nDelegate();

  @override
  Future<NotesL10n> load(Locale locale) {
    return SynchronousFuture<NotesL10n>(lookupNotesL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_NotesL10nDelegate old) => false;
}

NotesL10n lookupNotesL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return NotesL10nEn();
    case 'ko':
      return NotesL10nKo();
    case 'ru':
      return NotesL10nRu();
    case 'zh':
      return NotesL10nZh();
  }

  throw FlutterError(
    'NotesL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
