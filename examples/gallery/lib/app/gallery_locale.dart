import 'package:flutter/widgets.dart';
import 'package:gallery/l10n/gallery_l10n.dart';

/// The languages the gallery is written in, and the way to switch between them.
///
/// The choice lives above `MaterialApp`, because that is what `locale` is read
/// from — but the control that changes it lives on the hub, well below. An
/// inherited widget is what bridges those two, and it carries only the setter:
/// which language is in force is already answered by
/// `Localizations.localeOf`, and a second copy of that answer would be one
/// that could disagree.
class GalleryLocaleScope extends InheritedWidget {
  /// Lets the subtree switch the app's language through [select].
  const GalleryLocaleScope({
    required this.select,
    required super.child,
    super.key,
  });

  /// Every language the gallery is translated into, in menu order.
  ///
  /// Read from the generated list rather than written again beside it. The
  /// translations are what decide the set, and a second copy could only ever
  /// disagree with them — offering a language nobody translated, or hiding one
  /// somebody did.
  static List<Locale> get supported => GalleryL10n.supportedLocales;

  /// What each language calls itself.
  ///
  /// Endonyms rather than translations: a reader looking for their own
  /// language recognises it written the way they write it, and would not
  /// recognise it named in a language they cannot read.
  static const endonyms = {
    'en': 'English',
    'ru': 'Русский',
    'zh': '中文',
    'ko': '한국어',
  };

  /// Switches the app to another language.
  final ValueChanged<Locale> select;

  /// The switcher above [context].
  static GalleryLocaleScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<GalleryLocaleScope>();
    assert(scope != null, 'No GalleryLocaleScope above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(GalleryLocaleScope oldWidget) =>
      select != oldWidget.select;
}
