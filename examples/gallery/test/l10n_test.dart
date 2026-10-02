import 'dart:convert';
import 'dart:io';

import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:codegen_basics/l10n/codegen_basics_l10n.dart';
import 'package:flow_scopes/l10n/flow_scopes_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/app/gallery_app.dart';
import 'package:gallery/app/gallery_locale.dart';
import 'package:gallery/catalog/catalog.dart';
import 'package:gallery/design/gallery_theme.dart';
import 'package:gallery/features/hub/hub_screen.dart';
import 'package:gallery/l10n/gallery_l10n.dart';
import 'package:graph_events/l10n/graph_events_l10n.dart';
import 'package:notes_app/l10n/notes_app_l10n.dart';

import 'support.dart';

void main() {
  testWidgets('the hub is written in the language in force', (tester) async {
    await tester.pumpWidget(
      galleryHarness(home: const HubScreen(), locale: const Locale('ru')),
    );
    await tester.pump();

    // The first section and its first card: a sliver list builds lazily, so
    // anything below the fold is not in the tree to be found.
    expect(find.text('СТАРТ'), findsOneWidget);
    expect(find.text('Двухфазный старт'), findsOneWidget);
    expect(find.text('ЭКРАН'), findsWidgets);
  });

  testWidgets('and in Chinese, where nothing is upper-cased', (tester) async {
    await tester.pumpWidget(
      galleryHarness(home: const HubScreen(), locale: const Locale('zh')),
    );
    await tester.pump();

    expect(find.text('启动'), findsOneWidget);
    expect(find.text('两阶段启动'), findsOneWidget);
  });

  testWidgets('and in Korean, where Hangul has no case either', (tester) async {
    await tester.pumpWidget(
      galleryHarness(home: const HubScreen(), locale: const Locale('ko')),
    );
    await tester.pump();

    expect(find.text('시작'), findsOneWidget);
    expect(find.text('두 단계 시작'), findsOneWidget);
  });

  testWidgets('choosing a language switches the whole app', (tester) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pumpAndSettle();

    expect(find.text('Two-phase startup'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-ru')));
    await tester.pumpAndSettle();

    expect(find.text('Двухфазный старт'), findsOneWidget);
    expect(find.text('Two-phase startup'), findsNothing);

    await tester.tap(find.byKey(const Key('language-zh')));
    await tester.pumpAndSettle();

    expect(find.text('两阶段启动'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-ko')));
    await tester.pumpAndSettle();

    expect(find.text('두 단계 시작'), findsOneWidget);
  });

  testWidgets('the gallery installs the inspector delegate rather than '
      'leaning on its fallback', (tester) async {
    await tester.pumpWidget(const GalleryApp());
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.localizationsDelegates,
      contains(CobaltInspectorL10n.delegate),
      reason:
          'the inspector reads the ambient locale with no delegate at all, so '
          'the screens would look right either way — only this says which of '
          'the two the gallery is actually demonstrating',
    );
    for (final delegate in const [
      NotesL10n.delegate,
      FlowScopesL10n.delegate,
      GraphEventsL10n.delegate,
      CodegenBasicsL10n.delegate,
    ]) {
      expect(
        app.localizationsDelegates,
        contains(delegate),
        reason:
            'the strings belong to the package that shows them, and this is '
            'where the app collects them — checked against GalleryApp rather '
            'than the test harness, because the harness is wiring this test '
            'wrote itself',
      );
    }
  });

  testWidgets('the inspector inside the gallery follows the switch too', (
    tester,
  ) async {
    final entry = buildCatalog(
      lookupGalleryL10n(const Locale('ru')),
    ).firstWhere((e) => e.id == 'inspector');

    await tester.pumpWidget(
      galleryHarness(
        home: Builder(builder: entry.open!),
        locale: const Locale('ru'),
      ),
    );
    // Two settles: the host shows its loading frame before the scope is
    // published, exactly as CobaltAppScope does anywhere else.
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Открыть сессионный скоуп'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-inspector')));
    await tester.pumpAndSettle();

    expect(
      find.text('Cobalt · инспектор'),
      findsOneWidget,
      reason:
          'what a reader sees, by whichever of the two routes got them there '
          '— the delegate is checked separately, because this cannot tell '
          'them apart',
    );
    expect(find.text('Дерево'), findsOneWidget);
  });

  testWidgets('a language Space Grotesk cannot write is set in one that can', (
    tester,
  ) async {
    Set<String> familiesOn(Finder finder) => {
      for (final text in tester.widgetList<Text>(finder))
        ?text.style?.fontFamily,
    };

    await tester.pumpWidget(
      galleryHarness(home: const HubScreen(), locale: const Locale('en')),
    );
    await tester.pump();

    expect(
      familiesOn(find.byType(Text)),
      contains('SpaceGrotesk_regular'),
      reason: 'English is what the gallery was drawn in',
    );

    await tester.pumpWidget(
      galleryHarness(home: const HubScreen(), locale: const Locale('ru')),
    );
    await tester.pump();

    final russian = familiesOn(find.byType(Text));
    expect(russian, contains('Manrope_regular'));
    expect(
      russian,
      isNot(contains('SpaceGrotesk_regular')),
      reason:
          'Space Grotesk has no Cyrillic, so a style still naming it is a call '
          'site that never learned about the language — and the symptom is a '
          'change of typeface in the middle of a word, not a crash',
    );
    expect(
      russian,
      contains('JetBrainsMono_regular'),
      reason: 'the mono face does cover Cyrillic and must not have moved',
    );
  });

  testWidgets('every themed surface carries the face, not just the ones in '
      'a screen', (tester) async {
    await tester.pumpWidget(
      galleryHarness(
        locale: const Locale('ru'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const ListTile(
                  title: Text('плитка'),
                  subtitle: Text('подпись плитки'),
                ),
                TextButton(
                  onPressed: () => ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('снек'))),
                  child: const Text('go'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    String? familyAt(String text) =>
        DefaultTextStyle.of(tester.element(find.text(text))).style.fontFamily;

    for (final text in ['плитка', 'подпись плитки', 'снек']) {
      expect(
        familyAt(text),
        'Manrope_regular',
        reason:
            'a ThemeData entry written as a bare TextStyle names no family, '
            'and Flutter takes that literally: the surface drops out of the '
            'type scale and is set in whatever the platform happens to have — '
            'in every language, English included',
      );
    }
  });

  test('the switcher offers exactly what was translated', () {
    expect(
      GalleryLocaleScope.supported,
      GalleryL10n.supportedLocales,
      reason:
          'the translations decide the set; a second list beside them '
          'could only ever disagree',
    );
    for (final locale in GalleryLocaleScope.supported) {
      expect(
        GalleryLocaleScope.endonyms,
        contains(locale.languageCode),
        reason:
            'a language with no endonym shows as its own language code, '
            'which is not what a reader is looking for',
      );
    }
  });

  test('a Cyrillic language is never set in a face that cannot write it', () {
    // The rule defaults the other way — anything unclassified gets Manrope —
    // so what this catches is the opposite mistake: adding a language to the
    // house face because it looked Latin enough in the list.
    const cyrillic = {'ru', 'uk', 'be', 'bg', 'sr', 'mk', 'kk'};

    for (final locale in GalleryL10n.supportedLocales) {
      if (!cyrillic.contains(locale.languageCode)) continue;
      expect(
        GalleryFace.of(locale),
        isNot(GalleryFace.spaceGrotesk),
        reason:
            '${locale.languageCode} is written in Cyrillic, which Space '
            'Grotesk has no glyphs for',
      );
    }
  });

  test('every package the gallery mounts speaks the same languages', () {
    const delegates = {
      'notes_app': NotesL10n.supportedLocales,
      'flow_scopes': FlowScopesL10n.supportedLocales,
      'graph_events': GraphEventsL10n.supportedLocales,
      'codegen_basics': CodegenBasicsL10n.supportedLocales,
      'cobalt_inspector': CobaltInspectorL10n.supportedLocales,
    };

    delegates.forEach((package, supported) {
      expect(
        supported,
        GalleryL10n.supportedLocales,
        reason:
            "$package knows a different set of languages than the app it is "
            'mounted in, so on the odd one out its screens quietly come back '
            'in English while everything around them changes',
      );
    });
  });

  testWidgets('no screen keeps an English line under Russian', (tester) async {
    // Every plain English message, from every package the gallery mounts.
    // Messages with placeholders are skipped: they never render literally, so
    // an equality check on them would prove nothing either way.
    final english = <String>{};
    for (final path in [
      '../notes_app/l10n/notes_app_en.arb',
      '../flow_scopes/l10n/flow_scopes_en.arb',
      '../graph_events/l10n/graph_events_en.arb',
      '../codegen_basics/l10n/codegen_basics_en.arb',
      'l10n/gallery_en.arb',
    ]) {
      final decoded =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        if (entry.key.startsWith('@') || entry.value is! String) continue;
        final value = entry.value as String;
        if (!value.contains('{')) english.add(value);
      }
    }
    expect(english, isNotEmpty);

    for (final entry in buildCatalog(
      lookupGalleryL10n(const Locale('ru')),
    ).where((e) => e.isOpenable)) {
      await tester.pumpWidget(
        galleryHarness(
          home: Builder(key: ValueKey(entry.id), builder: entry.open!),
          locale: const Locale('ru'),
        ),
      );
      // Two settles: the host shows its loading frame before the scope is
      // published, exactly as CobaltAppScope does anywhere else.
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      final left = {
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          ?text.data,
      }.intersection(english);

      expect(
        left,
        isEmpty,
        reason:
            '${entry.id} still renders these in English under a Russian app — '
            'a call site that never learned about the language shows up as a '
            'sentence in the wrong one, not as a crash',
      );
    }
  });

  test('the catalog carries no prose of its own', () {
    final english = buildCatalog(englishStrings);
    final russian = buildCatalog(lookupGalleryL10n(const Locale('ru')));

    expect(
      russian.map((e) => e.id),
      english.map((e) => e.id),
      reason:
          'an id is identity — routes and tests key on it, so it is the '
          'one thing that must not move with the language',
    );
    for (var i = 0; i < english.length; i++) {
      expect(
        russian[i].title,
        isNot(english[i].title),
        reason:
            '${english[i].id} reads the same in both languages, which means '
            'it is still a literal in catalog.dart rather than a string',
      );
      for (var p = 0; p < english[i].points.length; p++) {
        expect(russian[i].points[p], isNot(english[i].points[p]));
      }
    }
  });

  test('every translation covers the template, key for key', () {
    Set<String> keysOf(String name) {
      final decoded =
          jsonDecode(File('l10n/$name.arb').readAsStringSync())
              as Map<String, dynamic>;
      return decoded.keys.where((key) => !key.startsWith('@')).toSet();
    }

    final template = keysOf('gallery_en');
    expect(template, isNotEmpty);

    for (final locale in ['ru', 'zh', 'ko']) {
      expect(
        keysOf('gallery_$locale'),
        template,
        reason:
            'a missing translation is only a warning from gen-l10n, and then '
            'that one line silently comes back in English — in a catalog of '
            'prose that reads as a typo rather than as a gap',
      );
    }
  });
}
