import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'flow_scopes_l10n_en.dart';
import 'flow_scopes_l10n_ru.dart';
import 'flow_scopes_l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of FlowScopesL10n
/// returned by `FlowScopesL10n.of(context)`.
///
/// Applications need to include `FlowScopesL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/flow_scopes_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FlowScopesL10n.localizationsDelegates,
///   supportedLocales: FlowScopesL10n.supportedLocales,
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
/// be consistent with the languages listed in the FlowScopesL10n.supportedLocales
/// property.
abstract class FlowScopesL10n {
  FlowScopesL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FlowScopesL10n of(BuildContext context) {
    return Localizations.of<FlowScopesL10n>(context, FlowScopesL10n)!;
  }

  static const LocalizationsDelegate<FlowScopesL10n> delegate =
      _FlowScopesL10nDelegate();

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

  /// Title of the navigation-flow example.
  ///
  /// In en, this message translates to:
  /// **'Cobalt · flow scopes'**
  String get appTitle;

  /// Action that opens the live scope tree.
  ///
  /// In en, this message translates to:
  /// **'what is alive right now'**
  String get whatIsAlive;

  /// Heading above the list of flows.
  ///
  /// In en, this message translates to:
  /// **'Open a flow'**
  String get openAFlow;

  /// What entering a flow does to the graph.
  ///
  /// In en, this message translates to:
  /// **'the scope is created on entry and disposed on exit'**
  String get openAFlowDetail;

  /// One order flow to enter.
  ///
  /// In en, this message translates to:
  /// **'Order {id}'**
  String order(String id);

  /// The tabbed flow.
  ///
  /// In en, this message translates to:
  /// **'Workspace (tabs)'**
  String get workspaceTabs;

  /// How the tabbed flow is built.
  ///
  /// In en, this message translates to:
  /// **'a shell scope plus a scope per tab'**
  String get workspaceTabsDetail;

  /// Heading above what the graph has done.
  ///
  /// In en, this message translates to:
  /// **'Event log'**
  String get eventLog;

  /// Shown while the graph has done nothing.
  ///
  /// In en, this message translates to:
  /// **'nothing yet'**
  String get logEmpty;

  /// A scope appeared. The subject is a scope name, not prose.
  ///
  /// In en, this message translates to:
  /// **'{subject} scope built'**
  String scopeBuilt(String subject);

  /// A scope went away.
  ///
  /// In en, this message translates to:
  /// **'{subject} scope disposed'**
  String scopeDisposed(String subject);

  /// A flow built its draft.
  ///
  /// In en, this message translates to:
  /// **'draft {order} created'**
  String draftCreated(String order);

  /// A flow's draft went with it.
  ///
  /// In en, this message translates to:
  /// **'draft {order} disposed'**
  String draftDisposed(String order);

  /// Title of the live scope tree screen.
  ///
  /// In en, this message translates to:
  /// **'Scope tree'**
  String get scopeTree;

  /// One node of the tree: its state, which is an Cobalt identifier, and how many scopes hang from it.
  ///
  /// In en, this message translates to:
  /// **'{state} · {count, plural, =0{no children} =1{1 child} other{{count} children}}'**
  String scopeNode(String state, int count);

  /// Title above the two order screens.
  ///
  /// In en, this message translates to:
  /// **'Checkout flow'**
  String get checkoutFlow;

  /// Which scope the screen is inside.
  ///
  /// In en, this message translates to:
  /// **'scope: {name}'**
  String scopeLine(String name);

  /// Which draft was resolved, and which object it is, so a rebuild is visible.
  ///
  /// In en, this message translates to:
  /// **'order {order} · instance {instance}'**
  String draftLine(String order, String instance);

  /// Moves to the next screen of the same flow.
  ///
  /// In en, this message translates to:
  /// **'Continue to payment'**
  String get continueToPayment;

  /// What that move proves.
  ///
  /// In en, this message translates to:
  /// **'same flow — the draft must survive'**
  String get continueToPaymentDetail;

  /// Changes what the flow is about.
  ///
  /// In en, this message translates to:
  /// **'Switch to order {other}'**
  String switchToOrder(String other);

  /// Why that rebuilds the scope.
  ///
  /// In en, this message translates to:
  /// **'identity changes — a new scope is built'**
  String get switchToOrderDetail;

  /// Goes back out of the flow.
  ///
  /// In en, this message translates to:
  /// **'Leave the flow'**
  String get leaveFlow;

  /// What leaving disposes.
  ///
  /// In en, this message translates to:
  /// **'the scope and the draft go with it'**
  String get leaveFlowDetail;

  /// Title of the tabbed flow.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get workspace;

  /// The scope shared by every tab.
  ///
  /// In en, this message translates to:
  /// **'shell scope: {name}'**
  String shellScope(String name);

  /// Which tab's marker was resolved, and out of which scope.
  ///
  /// In en, this message translates to:
  /// **'{label} · scope {name}'**
  String markerLine(String label, String name);

  /// Why switching tabs disposes nothing.
  ///
  /// In en, this message translates to:
  /// **'Switch tabs and come back: nothing is rebuilt. A branch is kept alive, not kept visible, so its scope lives until the whole workspace closes.'**
  String get tabsExplained;

  /// First tab.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get tabFeed;

  /// Second tab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// The flow of three top-level routes.
  ///
  /// In en, this message translates to:
  /// **'Cart → checkout → payment'**
  String get openCart;

  /// How the cart flow is built.
  ///
  /// In en, this message translates to:
  /// **'three top-level routes, one scope'**
  String get openCartDetail;

  /// The cart flow built its draft.
  ///
  /// In en, this message translates to:
  /// **'cart draft created'**
  String get cartCreated;

  /// The cart flow's draft went with it.
  ///
  /// In en, this message translates to:
  /// **'cart draft disposed'**
  String get cartDisposed;

  /// First screen of the cart flow.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get stepCart;

  /// Second screen of the cart flow.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get stepCheckout;

  /// Last screen of the cart flow.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get stepPayment;

  /// Moves to the checkout screen of the cart flow.
  ///
  /// In en, this message translates to:
  /// **'Continue to checkout'**
  String get continueToCheckout;

  /// What moving to the next step proves.
  ///
  /// In en, this message translates to:
  /// **'another top-level route — the draft must survive'**
  String get cartNextDetail;

  /// Which cart draft was resolved, so a rebuild is visible.
  ///
  /// In en, this message translates to:
  /// **'cart draft · instance {instance}'**
  String cartLine(String instance);
}

class _FlowScopesL10nDelegate extends LocalizationsDelegate<FlowScopesL10n> {
  const _FlowScopesL10nDelegate();

  @override
  Future<FlowScopesL10n> load(Locale locale) {
    return SynchronousFuture<FlowScopesL10n>(lookupFlowScopesL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_FlowScopesL10nDelegate old) => false;
}

FlowScopesL10n lookupFlowScopesL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return FlowScopesL10nEn();
    case 'ru':
      return FlowScopesL10nRu();
    case 'zh':
      return FlowScopesL10nZh();
  }

  throw FlutterError(
    'FlowScopesL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
