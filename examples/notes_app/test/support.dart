import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/l10n/notes_app_l10n.dart';
import 'package:notes_app/app/app_startup.dart';

/// Builds the graph without mounting the app.
///
/// The same three pieces `CobaltAppScope` is given in `NotesApp.build`; the app
/// itself needs no such function, which is why this one lives in `test/`.
Future<CobaltScope> startNotesGraph({
  CobaltEnvironment environment = notesEnvironment,
}) => cobaltTestScope(
  root: NotesScope(environment),
  bootstrap: cobaltBootstrapSteps(environment),
  rootName: cobaltRootScopeName,
);

/// Mounts one screen with the notes graph beneath it.
///
/// There is no app widget any more — the gallery owns that, and every screen
/// here is reached directly. So a test mounts exactly the screen it is about.
Widget notesScreenUnderTest(
  Widget screen, {
  CobaltEnvironment environment = notesEnvironment,
}) => MaterialApp(
  // The gallery registers this delegate beside its own; a test mounting one
  // screen on its own has to supply it here.
  localizationsDelegates: const [
    NotesL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: NotesL10n.supportedLocales,
  home: CobaltAppScope(
    root: NotesScope(environment),
    bootstrap: () => cobaltBootstrapSteps(environment),
    rootName: cobaltRootScopeName,
    loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
    child: screen,
  ),
);
