import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'codegen_basics_l10n_en.dart';
import 'codegen_basics_l10n_ru.dart';
import 'codegen_basics_l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CodegenBasicsL10n
/// returned by `CodegenBasicsL10n.of(context)`.
///
/// Applications need to include `CodegenBasicsL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/codegen_basics_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CodegenBasicsL10n.localizationsDelegates,
///   supportedLocales: CodegenBasicsL10n.supportedLocales,
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
/// be consistent with the languages listed in the CodegenBasicsL10n.supportedLocales
/// property.
abstract class CodegenBasicsL10n {
  CodegenBasicsL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CodegenBasicsL10n of(BuildContext context) {
    return Localizations.of<CodegenBasicsL10n>(context, CodegenBasicsL10n)!;
  }

  static const LocalizationsDelegate<CodegenBasicsL10n> delegate =
      _CodegenBasicsL10nDelegate();

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

  /// Title of the generated-container example.
  ///
  /// In en, this message translates to:
  /// **'Cobalt codegen basics'**
  String get appTitle;

  /// Which build the graph was started for.
  ///
  /// In en, this message translates to:
  /// **'environment: {name}'**
  String environment(String name);

  /// The line a parameterized registration produces: the name comes from the call site, the environment from the graph.
  ///
  /// In en, this message translates to:
  /// **'hello {name} from {environment}'**
  String greeting(String name, String environment);

  /// Button that adds one to the counter.
  ///
  /// In en, this message translates to:
  /// **'increment'**
  String get increment;

  /// Shown while the lazy leaderboard is being built on first use.
  ///
  /// In en, this message translates to:
  /// **'loading the leaderboard…'**
  String get leaderboardLoading;

  /// The lazy leaderboard, once built.
  ///
  /// In en, this message translates to:
  /// **'leaderboard ready: {entries} entries'**
  String leaderboardReady(int entries);
}

class _CodegenBasicsL10nDelegate
    extends LocalizationsDelegate<CodegenBasicsL10n> {
  const _CodegenBasicsL10nDelegate();

  @override
  Future<CodegenBasicsL10n> load(Locale locale) {
    return SynchronousFuture<CodegenBasicsL10n>(
      lookupCodegenBasicsL10n(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_CodegenBasicsL10nDelegate old) => false;
}

CodegenBasicsL10n lookupCodegenBasicsL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return CodegenBasicsL10nEn();
    case 'ru':
      return CodegenBasicsL10nRu();
    case 'zh':
      return CodegenBasicsL10nZh();
  }

  throw FlutterError(
    'CodegenBasicsL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
