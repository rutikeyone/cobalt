import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/catalog/catalog.dart';
import 'package:gallery/catalog/lazy_async_graph.dart';

import 'support.dart';

void main() {
  Future<void> openEntry(WidgetTester tester) async {
    final entry = buildCatalog(
      englishStrings,
    ).singleWhere((e) => e.id == 'lazy-async');
    await tester.pumpWidget(
      galleryHarness(home: Builder(builder: entry.open!)),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
  }

  String builds(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('engine-builds'))).data!;

  testWidgets('startup finishes without building the engine', (tester) async {
    await openEntry(tester);

    expect(builds(tester), 'engine not built yet');
  });

  testWidgets('the first visit waits for one build; the second does not', (
    tester,
  ) async {
    await openEntry(tester);

    await tester.tap(find.byKey(const Key('open-search')));
    await tester.pump();
    await tester.pump();
    expect(find.text('building the engine…'), findsOneWidget);
    expect(find.byKey(const Key('engine-ready')), findsNothing);

    await tester.pump(SearchEngineFactory.buildTime);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('engine-ready')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(builds(tester), 'engine built once');

    await tester.tap(find.byKey(const Key('open-search')));
    await tester.pump();
    expect(
      find.text('building the engine…'),
      findsNothing,
      reason:
          'built already, so the builder renders it without a loading frame',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('engine-ready')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(builds(tester), 'engine built once');
  });
}
