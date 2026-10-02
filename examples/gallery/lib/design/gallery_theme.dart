import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The palette from the design canvas, transcribed.
///
/// The two accents carry one distinction and only that one: [screen] marks an
/// example you can open on a device, [terminal] one that prints. They share
/// chroma and lightness and differ only in hue, so neither reads as more
/// important than the other.
abstract final class GalleryColors {
  static const canvas = Color(0xFF1B1E24);
  static const card = Color(0xFF262A31);
  static const terminalSurface = Color(0xFF13161B);
  static const hairline = Color(0xFF383D46);

  static const text = Color(0xFFEDEFF2);
  static const textMuted = Color(0xFFA3A9B4);
  static const textFaint = Color(0xFF7C838F);

  static const screen = Color(0xFF5FD4C8);
  static const terminal = Color(0xFFE0A85F);
}

/// The face the interface is set in, chosen by what the language needs.
///
/// Space Grotesk has no Cyrillic — Google Fonts ships it as latin, latin-ext
/// and vietnamese and nothing else. Set a Russian screen in it and the Latin
/// words render in Space Grotesk while everything around them falls back to
/// whatever the platform happens to have, which is a change of typeface in the
/// middle of «Bootstrap-шаги» and a different one on iOS than on Android. A
/// face that cannot write the language is the wrong face for that language.
///
/// Manrope is the substitute rather than a neutral UI face because switching
/// language should not switch the app's personality: it is the same modern
/// semi-geometric grotesque, and it covers Cyrillic properly.
///
/// Chinese and Korean need no entry. No webfont here can carry CJK or Hangul
/// at a size worth downloading, the platform's own face is what every Chinese
/// and Korean interface is set in anyway, and Latin beside it is the ordinary
/// mixed-script pairing rather than an accident.
enum GalleryFace {
  /// Space Grotesk: the gallery's own face, for the scripts it can write.
  spaceGrotesk,

  /// Manrope: for Cyrillic, which Space Grotesk has no glyphs for.
  manrope;

  /// Languages set in the house face.
  ///
  /// Chinese and Korean are here despite not being Latin: no webfont worth
  /// downloading carries CJK or Hangul, so those glyphs come from the platform
  /// whichever face we name, and the Latin beside them may as well be the
  /// gallery's own.
  static const _houseFace = {'en', 'zh', 'ko'};

  /// The face [locale] needs.
  ///
  /// Listed the way round that makes forgetting cheap. Manrope writes Latin
  /// and Cyrillic both, so a language nobody classified is merely not in the
  /// house face — where the other way round it would be set in a face that
  /// cannot write its words, which is the whole reason this enum exists.
  static GalleryFace of(Locale locale) =>
      _houseFace.contains(locale.languageCode) ? spaceGrotesk : manrope;

  TextStyle _display({
    required double fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) => switch (this) {
    GalleryFace.spaceGrotesk => GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    ),
    GalleryFace.manrope => GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    ),
  };

  TextTheme _textTheme(TextTheme base) => switch (this) {
    GalleryFace.spaceGrotesk => GoogleFonts.spaceGroteskTextTheme(base),
    GalleryFace.manrope => GoogleFonts.manropeTextTheme(base),
  };
}

/// Type scale from the canvas. Grotesk for the interface, mono for anything
/// the machine said.
///
/// Read through [of], because the display face depends on the language. The
/// mono styles do not: JetBrains Mono covers Cyrillic, so the one place the
/// gallery quotes the machine reads the same in every language — which is the
/// point, since what it quotes is code.
@immutable
class GalleryText {
  /// Sets the display styles in [face].
  const GalleryText(this.face);

  /// The scale for the language in force above [context].
  factory GalleryText.of(BuildContext context) =>
      GalleryText(GalleryFace.of(Localizations.localeOf(context)));

  /// The face the display styles are set in.
  final GalleryFace face;

  TextStyle get wordmark => face._display(
    fontSize: 25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.05,
    color: GalleryColors.text,
  );

  TextStyle get title => face._display(
    fontSize: 27,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: GalleryColors.text,
  );

  TextStyle get cardTitle => face._display(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: GalleryColors.text,
  );

  TextStyle get body =>
      face._display(fontSize: 14, height: 1.5, color: const Color(0xFFD2D6DC));

  TextStyle get cardBody =>
      face._display(fontSize: 13, height: 1.45, color: GalleryColors.textMuted);

  TextStyle get lede =>
      face._display(fontSize: 15, height: 1.5, color: GalleryColors.textMuted);

  TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 11.5,
    height: 1.7,
    color: const Color(0xFFC8CCD3),
  );

  TextStyle get monoCaps => GoogleFonts.jetBrainsMono(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.1,
    color: GalleryColors.textFaint,
  );

  TextStyle get badge =>
      GoogleFonts.jetBrainsMono(fontSize: 9.5, letterSpacing: 0.7, height: 1.4);

  TextStyle get subtitle => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    letterSpacing: 0.2,
    color: GalleryColors.textFaint,
  );
}

/// One theme for the whole app, examples included, set in [face].
///
/// Every example renders under this and nothing else. An example that brought
/// its own palette would be showing you two designs at once — and the seam
/// between them reads as a bug long before it reads as a distinction.
///
/// [face] is a parameter rather than a lookup because a `ThemeData` is built
/// above `Localizations`, where there is no language yet to ask about. The app
/// resolves it in `MaterialApp.builder`, which is below both.
ThemeData galleryTheme(GalleryFace face) {
  final text = GalleryText(face);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: GalleryColors.screen,
        brightness: Brightness.dark,
      ).copyWith(
        primary: GalleryColors.screen,
        onPrimary: GalleryColors.canvas,
        secondary: GalleryColors.terminal,
        onSecondary: GalleryColors.canvas,
        surface: GalleryColors.canvas,
        onSurface: GalleryColors.text,
        onSurfaceVariant: GalleryColors.textMuted,
        surfaceContainerLowest: GalleryColors.terminalSurface,
        surfaceContainerLow: GalleryColors.canvas,
        surfaceContainer: GalleryColors.card,
        surfaceContainerHigh: GalleryColors.card,
        surfaceContainerHighest: GalleryColors.card,
        outline: GalleryColors.hairline,
        outlineVariant: GalleryColors.hairline,
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
  );

  return base.copyWith(
    scaffoldBackgroundColor: GalleryColors.canvas,
    canvasColor: GalleryColors.canvas,
    textTheme: face._textTheme(base.textTheme),
    // Flat and untinted, so an example's app bar is the same colour scrolled
    // as it is at rest. Material 3 tints it on scroll by default, which on a
    // dark canvas looks like the background changed underneath you.
    appBarTheme: AppBarTheme(
      backgroundColor: GalleryColors.canvas,
      foregroundColor: GalleryColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: text.cardTitle.copyWith(fontSize: 17),
    ),
    cardTheme: CardThemeData(
      color: GalleryColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: GalleryColors.hairline),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: GalleryColors.hairline,
      space: 1,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: GalleryColors.textMuted,
      textColor: GalleryColors.text,
      // Built from the scale rather than written fresh: a bare TextStyle here
      // names no family, and Flutter takes that literally — the subtitle drops
      // out of the type scale and is set in whatever the platform has.
      subtitleTextStyle: text.cardBody.copyWith(
        fontSize: 12.5,
        color: GalleryColors.textFaint,
      ),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: GalleryColors.screen,
      collapsedIconColor: GalleryColors.textFaint,
      textColor: GalleryColors.text,
      collapsedTextColor: GalleryColors.text,
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      shape: Border(),
      collapsedShape: Border(),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: GalleryColors.card,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: GalleryColors.card,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: GalleryColors.card,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: GalleryColors.card,
      contentTextStyle: text.body.copyWith(color: GalleryColors.text),
      behavior: SnackBarBehavior.floating,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: GalleryColors.screen,
      unselectedLabelColor: GalleryColors.textFaint,
      indicatorColor: GalleryColors.screen,
      dividerColor: GalleryColors.hairline,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: GalleryColors.card,
      selectedColor: GalleryColors.screen.withValues(alpha: 0.18),
      side: const BorderSide(color: GalleryColors.hairline),
      labelStyle: text.cardBody,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// The gallery's palette, handed to the Cobalt inspector.
///
/// Written out rather than derived from [galleryTheme] to show what the knob
/// is for: an app with its own colours names them, and the inspector uses
/// those instead of the ones it would infer.
CobaltInspectorThemeData galleryInspectorTheme(BuildContext context) =>
    CobaltInspectorThemeData(
      background: GalleryColors.canvas,
      surface: GalleryColors.card,
      onSurface: GalleryColors.text,
      muted: GalleryColors.textMuted,
      outline: GalleryColors.hairline,
      accent: GalleryColors.screen,
      scope: GalleryColors.screen,
      startup: const Color(0xFF8FD98F),
      instance: GalleryColors.textFaint,
      failure: const Color(0xFFE0705F),
      warning: GalleryColors.terminal,
      monospace: GalleryText.of(context).mono,
    );
