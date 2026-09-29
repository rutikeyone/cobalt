import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:codegen_basics/l10n/codegen_basics_l10n.dart';
import 'package:flow_scopes/l10n/flow_scopes_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gallery/app/gallery_locale.dart';
import 'package:gallery/app/shots.dart';
import 'package:gallery/design/gallery_theme.dart';
import 'package:gallery/features/hub/hub_screen.dart';
import 'package:gallery/l10n/gallery_l10n.dart';
import 'package:graph_events/l10n/graph_events_l10n.dart';
import 'package:notes_app/l10n/notes_app_l10n.dart';

/// The gallery owns no graph of its own.
///
/// Every example brings its own, built when you open it and disposed when you
/// leave — which is the thing the gallery is really demonstrating, so putting
/// a container above them all would undercut it.
///
/// It does own the language. `CobaltInspectorL10n.delegate` is registered here
/// beside the gallery's own: the inspector renders in the host's language
/// without it, but installing it is the documented way, and a gallery that
/// showed the fallback rather than the intended path would be teaching the
/// wrong one.
class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  Locale? _locale;

  void _select(Locale locale) => setState(() => _locale = locale);

  @override
  Widget build(BuildContext context) => GalleryLocaleScope(
    select: _select,
    child: MaterialApp(
      onGenerateTitle: (context) => GalleryL10n.of(context).appTitle,
      // The gallery exists to be looked at, including in screenshots for the
      // README. A debug ribbon across the corner of every one of them is
      // noise about the build, not about Cobalt.
      debugShowCheckedModeBanner: false,
      // Built again below `Localizations`, where there is a language to ask
      // about: the face the interface is set in depends on it, and a
      // `ThemeData` handed to `MaterialApp` is assembled above that. What
      // arrives here as `child` is the navigator, so every screen is inside.
      theme: galleryTheme(GalleryFace.spaceGrotesk),
      builder: (context, child) => Theme(
        data: galleryTheme(GalleryFace.of(Localizations.localeOf(context))),
        child: child!,
      ),
      locale: _locale,
      localizationsDelegates: const [
        GalleryL10n.delegate,
        // Every package whose screens the gallery mounts brings its own, which
        // is what a multi-package app looks like: the strings belong to the
        // package that shows them, and the app collects the delegates.
        NotesL10n.delegate,
        FlowScopesL10n.delegate,
        GraphEventsL10n.delegate,
        CodegenBasicsL10n.delegate,
        CobaltInspectorL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: GalleryLocaleScope.supported,
      home: const HubScreen(),
      // A link — `cobaltgallery:///shot/log` — is pushed as a named route.
      // Anything but a known shot lands on the hub rather than on an error.
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: shotFor(settings.name) ?? (_) => const HubScreen(),
      ),
    ),
  );
}
