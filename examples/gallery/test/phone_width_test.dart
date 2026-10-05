import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/catalog/catalog.dart';
import 'package:gallery/features/hub/hub_screen.dart';

import 'support.dart';

/// Every screen the gallery shows, at the width of a small phone, in every
/// language it ships — the width a Russian or Korean label is most likely to
/// run past, which a desktop-sized test surface never shows.
void main() {
  for (final locale in const [
    Locale('en'),
    Locale('ko'),
    Locale('ru'),
    Locale('zh'),
  ]) {
    testWidgets('the hub fits a phone in $locale', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 800 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        galleryHarness(home: const HubScreen(), locale: locale),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('every openable entry fits a phone in $locale', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 800 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final openable = buildCatalog(
        englishStrings,
      ).where((e) => e.isOpenable).toList();

      for (final entry in openable) {
        await tester.pumpWidget(
          galleryHarness(
            home: Builder(key: ValueKey(entry.id), builder: entry.open!),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.title} ($locale)',
        );
      }
    });
  }
}
