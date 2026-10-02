import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'graph_events_l10n_en.dart';
import 'graph_events_l10n_ko.dart';
import 'graph_events_l10n_ru.dart';
import 'graph_events_l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of GraphEventsL10n
/// returned by `GraphEventsL10n.of(context)`.
///
/// Applications need to include `GraphEventsL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/graph_events_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: GraphEventsL10n.localizationsDelegates,
///   supportedLocales: GraphEventsL10n.supportedLocales,
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
/// be consistent with the languages listed in the GraphEventsL10n.supportedLocales
/// property.
abstract class GraphEventsL10n {
  GraphEventsL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static GraphEventsL10n of(BuildContext context) {
    return Localizations.of<GraphEventsL10n>(context, GraphEventsL10n)!;
  }

  static const LocalizationsDelegate<GraphEventsL10n> delegate =
      _GraphEventsL10nDelegate();

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

  /// Title of the graph-events example.
  ///
  /// In en, this message translates to:
  /// **'Cobalt · observability'**
  String get appTitle;

  /// Action that opens talker's screen.
  ///
  /// In en, this message translates to:
  /// **'the live log'**
  String get liveLog;

  /// What the list underneath is.
  ///
  /// In en, this message translates to:
  /// **'Every event below is the graph reporting itself'**
  String get everyEvent;

  /// Why the entries are colour-coded and filterable.
  ///
  /// In en, this message translates to:
  /// **'CobaltTalkerObserver files each kind under its own title, so the log screen can filter them apart.'**
  String get everyEventDetail;

  /// Action that pushes a child scope.
  ///
  /// In en, this message translates to:
  /// **'Open a session scope'**
  String get openSession;

  /// What that action makes the graph report.
  ///
  /// In en, this message translates to:
  /// **'a push, an async init, some instances'**
  String get openSessionDetail;

  /// Action that pushes a scope whose teardown fails.
  ///
  /// In en, this message translates to:
  /// **'Open one that will not close'**
  String get openBrokenSession;

  /// Why that scope is different.
  ///
  /// In en, this message translates to:
  /// **'its teardown throws, on purpose'**
  String get openBrokenSessionDetail;

  /// Action that disposes the pushed scope.
  ///
  /// In en, this message translates to:
  /// **'Close the session'**
  String get closeSession;

  /// Shown when there is no session scope to close.
  ///
  /// In en, this message translates to:
  /// **'nothing open'**
  String get nothingOpen;

  /// Which scope would be closed.
  ///
  /// In en, this message translates to:
  /// **'scope \"{name}\"'**
  String scopeNamed(String name);

  /// How many events the log holds.
  ///
  /// In en, this message translates to:
  /// **'Events recorded'**
  String get eventsRecorded;

  /// Shown while nothing has gone wrong yet.
  ///
  /// In en, this message translates to:
  /// **'No failures reported'**
  String get noFailures;

  /// How to make a failure happen.
  ///
  /// In en, this message translates to:
  /// **'close the session that will not close'**
  String get noFailuresDetail;

  /// A failure report: the kind of event, and how many events preceded it.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {count, plural, =1{1 breadcrumb} other{{count} breadcrumbs}}'**
  String reportSummary(String kind, int count);
}

class _GraphEventsL10nDelegate extends LocalizationsDelegate<GraphEventsL10n> {
  const _GraphEventsL10nDelegate();

  @override
  Future<GraphEventsL10n> load(Locale locale) {
    return SynchronousFuture<GraphEventsL10n>(lookupGraphEventsL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_GraphEventsL10nDelegate old) => false;
}

GraphEventsL10n lookupGraphEventsL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return GraphEventsL10nEn();
    case 'ko':
      return GraphEventsL10nKo();
    case 'ru':
      return GraphEventsL10nRu();
    case 'zh':
      return GraphEventsL10nZh();
  }

  throw FlutterError(
    'GraphEventsL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
