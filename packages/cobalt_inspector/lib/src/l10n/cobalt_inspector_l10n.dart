import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'cobalt_inspector_l10n_en.dart';
import 'cobalt_inspector_l10n_ru.dart';
import 'cobalt_inspector_l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CobaltInspectorL10n
/// returned by `CobaltInspectorL10n.of(context)`.
///
/// Applications need to include `CobaltInspectorL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/cobalt_inspector_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CobaltInspectorL10n.localizationsDelegates,
///   supportedLocales: CobaltInspectorL10n.supportedLocales,
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
/// be consistent with the languages listed in the CobaltInspectorL10n.supportedLocales
/// property.
abstract class CobaltInspectorL10n {
  CobaltInspectorL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CobaltInspectorL10n? of(BuildContext context) {
    return Localizations.of<CobaltInspectorL10n>(context, CobaltInspectorL10n);
  }

  static const LocalizationsDelegate<CobaltInspectorL10n> delegate =
      _CobaltInspectorL10nDelegate();

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

  /// App bar title of the inspector screen.
  ///
  /// In en, this message translates to:
  /// **'Cobalt · inspector'**
  String get inspectorTitle;

  /// Action that stops the log from repainting.
  ///
  /// In en, this message translates to:
  /// **'hold the view still'**
  String get pauseTooltip;

  /// Action that lets the log repaint again.
  ///
  /// In en, this message translates to:
  /// **'follow the graph again'**
  String get resumeTooltip;

  /// Action that empties the log.
  ///
  /// In en, this message translates to:
  /// **'forget what has been recorded'**
  String get clearTooltip;

  /// Tab showing the live scope tree.
  ///
  /// In en, this message translates to:
  /// **'Tree'**
  String get tabTree;

  /// Tab showing the instances the graph constructed.
  ///
  /// In en, this message translates to:
  /// **'Built'**
  String get tabBuilt;

  /// Tab showing every reported event.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get tabLog;

  /// Placeholder of the event log search field.
  ///
  /// In en, this message translates to:
  /// **'filter by message, scope or key'**
  String get logSearchHint;

  /// Shown when the graph has reported nothing at all.
  ///
  /// In en, this message translates to:
  /// **'Nothing reported yet'**
  String get logEmpty;

  /// Shown when the search and filters exclude every record.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that'**
  String get logNoMatch;

  /// Filter chip that selects every family.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get filterAll;

  /// Events about scopes appearing and going away.
  ///
  /// In en, this message translates to:
  /// **'scope'**
  String get familyScope;

  /// Events about bootstrap steps and phase-one initialization.
  ///
  /// In en, this message translates to:
  /// **'startup'**
  String get familyStartup;

  /// Events about instances being built and released.
  ///
  /// In en, this message translates to:
  /// **'instance'**
  String get familyInstance;

  /// Events about something going wrong.
  ///
  /// In en, this message translates to:
  /// **'failure'**
  String get familyFailure;

  /// Placeholder of the scope tree search field.
  ///
  /// In en, this message translates to:
  /// **'filter registrations'**
  String get treeSearchHint;

  /// Action that folds every node of the tree.
  ///
  /// In en, this message translates to:
  /// **'collapse all'**
  String get collapseAll;

  /// Action that unfolds every node of the tree.
  ///
  /// In en, this message translates to:
  /// **'expand all'**
  String get expandAll;

  /// Shown under a scope that registers nothing.
  ///
  /// In en, this message translates to:
  /// **'nothing registered'**
  String get treeNothingRegistered;

  /// Shown under a scope when the search excludes all of its registrations.
  ///
  /// In en, this message translates to:
  /// **'nothing matches'**
  String get treeNoMatch;

  /// Show built instances as one list, newest first.
  ///
  /// In en, this message translates to:
  /// **'flat'**
  String get groupingFlat;

  /// Gather built instances under the scope that built them.
  ///
  /// In en, this message translates to:
  /// **'by scope'**
  String get groupingByScope;

  /// Gather built instances by how long they live.
  ///
  /// In en, this message translates to:
  /// **'by lifetime'**
  String get groupingByLifetime;

  /// Shown when the graph has constructed nothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing built yet'**
  String get builtEmpty;

  /// Subtitle of a built instance: which scope built it, and who releases it.
  ///
  /// In en, this message translates to:
  /// **'in \"{scope}\" · {ownership}'**
  String builtWhere(String scope, String ownership);

  /// The scope retains this instance and releases it.
  ///
  /// In en, this message translates to:
  /// **'torn down with the scope'**
  String get ownedByScope;

  /// The scope does not retain this instance.
  ///
  /// In en, this message translates to:
  /// **'caller owns it'**
  String get ownedByCaller;

  /// Badge for a registration whose lifetime is no longer known.
  ///
  /// In en, this message translates to:
  /// **'gone'**
  String get lifetimeGone;

  /// Badge on a registration an override replaced.
  ///
  /// In en, this message translates to:
  /// **'overridden'**
  String get badgeOverridden;

  /// Badge on a registration a decorator wraps.
  ///
  /// In en, this message translates to:
  /// **'decorated'**
  String get badgeDecorated;

  /// Action that copies one log record to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'copy this record'**
  String get copyRecord;

  /// Confirmation after copying a record.
  ///
  /// In en, this message translates to:
  /// **'Record copied'**
  String get recordCopied;

  /// Field label: how loud the record is.
  ///
  /// In en, this message translates to:
  /// **'level'**
  String get fieldLevel;

  /// Field label: which scope the record is about.
  ///
  /// In en, this message translates to:
  /// **'scope'**
  String get fieldScope;

  /// Field label: which registration the record is about.
  ///
  /// In en, this message translates to:
  /// **'key'**
  String get fieldKey;

  /// Field label: how long the registration lives.
  ///
  /// In en, this message translates to:
  /// **'lifetime'**
  String get fieldLifetime;

  /// Field label: whether the scope holds on to the instance.
  ///
  /// In en, this message translates to:
  /// **'retained'**
  String get fieldRetained;

  /// Field label: the error carried by the record.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get fieldError;

  /// Field label: the stack trace carried by the record.
  ///
  /// In en, this message translates to:
  /// **'stack'**
  String get fieldStack;

  /// Field label: the record as structured data.
  ///
  /// In en, this message translates to:
  /// **'structured'**
  String get fieldStructured;

  /// Fact label: which scope declares the registration.
  ///
  /// In en, this message translates to:
  /// **'Owned by'**
  String get factOwnedBy;

  /// Fact label: how the registration is visible from here.
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get factReached;

  /// The registration belongs to a scope further up.
  ///
  /// In en, this message translates to:
  /// **'inherited from an ancestor'**
  String get reachedInherited;

  /// The registration belongs to the scope being looked at.
  ///
  /// In en, this message translates to:
  /// **'registered in this scope'**
  String get reachedHere;

  /// Fact label: whether an override stands in for the registration.
  ///
  /// In en, this message translates to:
  /// **'Replaced'**
  String get factReplaced;

  /// The registration was replaced by an override.
  ///
  /// In en, this message translates to:
  /// **'by an override — the real registration was skipped'**
  String get replacedByOverride;

  /// Fact label: the decorators wrapping the registration, innermost first.
  ///
  /// In en, this message translates to:
  /// **'Decorated by'**
  String get factDecoratedBy;

  /// Fact label: whether the scope releases the instance.
  ///
  /// In en, this message translates to:
  /// **'Torn down with the scope'**
  String get factTornDown;

  /// The scope releases it.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get tornDownYes;

  /// The scope does not release it.
  ///
  /// In en, this message translates to:
  /// **'no, the caller owns it'**
  String get tornDownNo;

  /// The lifetime is not known.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get tornDownUnknown;

  /// Fact label: the instance built by the explicit action.
  ///
  /// In en, this message translates to:
  /// **'Built'**
  String get factBuilt;

  /// Fact label: why the explicit build failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get factFailed;

  /// Action that resolves the registration for real.
  ///
  /// In en, this message translates to:
  /// **'Build it now'**
  String get buildItTitle;

  /// What the build action costs.
  ///
  /// In en, this message translates to:
  /// **'Creates the instance for real and logs it — this changes the graph you are looking at'**
  String get buildItSubtitle;

  /// Why a parameterized registration offers no build action.
  ///
  /// In en, this message translates to:
  /// **'Takes a parameter, so it cannot be built from here'**
  String get notBuildable;

  /// How much a scope node holds: its own registrations, and how many children hang off it.
  ///
  /// In en, this message translates to:
  /// **'{registrations} reg · {children, plural, =1{1 child} other{{children} children}}'**
  String nodeCounts(int registrations, int children);
}

class _CobaltInspectorL10nDelegate
    extends LocalizationsDelegate<CobaltInspectorL10n> {
  const _CobaltInspectorL10nDelegate();

  @override
  Future<CobaltInspectorL10n> load(Locale locale) {
    return SynchronousFuture<CobaltInspectorL10n>(
      lookupCobaltInspectorL10n(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_CobaltInspectorL10nDelegate old) => false;
}

CobaltInspectorL10n lookupCobaltInspectorL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return CobaltInspectorL10nEn();
    case 'ru':
      return CobaltInspectorL10nRu();
    case 'zh':
      return CobaltInspectorL10nZh();
  }

  throw FlutterError(
    'CobaltInspectorL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
