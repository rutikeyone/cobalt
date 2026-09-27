import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/catalog/catalog.dart';

import 'support.dart';

void main() {
  testWidgets('the inspector entry shows an override and a decorator', (
    tester,
  ) async {
    final entry = buildCatalog(
      englishStrings,
    ).singleWhere((e) => e.id == 'inspector');
    await tester.pumpWidget(
      galleryHarness(home: Builder(builder: entry.open!)),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-inspector')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('overridden-Settings')), findsOneWidget);
    expect(find.byKey(const Key('decorated-Query')), findsOneWidget);
  });
}
