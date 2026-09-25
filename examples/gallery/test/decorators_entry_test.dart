import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/catalog/catalog.dart';

import 'support.dart';

void main() {
  Future<void> openEntry(WidgetTester tester) async {
    final entry = buildCatalog(
      englishStrings,
    ).singleWhere((e) => e.id == 'decorators');
    await tester.pumpWidget(
      galleryHarness(home: Builder(builder: entry.open!)),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('shows the chain, innermost first', (tester) async {
    await openEntry(tester);

    expect(
      text(tester, 'decorator-chain'),
      'Station → CachingDecorator → LoggingDecorator',
    );
    expect(text(tester, 'station-calls'), 'not reached yet');
  });

  testWidgets('the cache answers a repeat; the log sees every answer', (
    tester,
  ) async {
    await openEntry(tester);

    await tester.tap(find.byKey(const Key('ask-Oslo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ask-Oslo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ask-Lima')));
    await tester.pump();

    expect(text(tester, 'station-calls'), 'reached 2 times');
    expect(find.text('Oslo 12°'), findsNWidgets(2));
    expect(find.text('Lima 12°'), findsOneWidget);
  });
}
