import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/catalog/async_transient_graph.dart';
import 'package:gallery/catalog/catalog.dart';

import 'support.dart';

void main() {
  Future<void> openEntry(WidgetTester tester) async {
    final entry = buildCatalog(
      englishStrings,
    ).singleWhere((e) => e.id == 'async-transient');
    await tester.pumpWidget(
      galleryHarness(home: Builder(builder: entry.open!)),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
  }

  String builds(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('report-builds'))).data!;

  testWidgets('startup builds no report', (tester) async {
    await openEntry(tester);

    expect(builds(tester), 'no report built yet');
  });

  testWidgets('every call is a build of its own', (tester) async {
    await openEntry(tester);

    await tester.tap(find.byKey(const Key('build-one')));
    await tester.pump(ReportFactory.buildTime);
    await tester.pumpAndSettle();
    expect(builds(tester), '1 report built');
    expect(find.textContaining('report #1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('build-one')));
    await tester.pump(ReportFactory.buildTime);
    await tester.pumpAndSettle();
    expect(builds(tester), '2 reports built');
    expect(find.textContaining('report #2'), findsOneWidget);
  });

  testWidgets('two at once are two builds, not one shared', (tester) async {
    await openEntry(tester);

    await tester.tap(find.byKey(const Key('build-two')));
    await tester.pump();
    expect(builds(tester), '2 reports built');

    await tester.pump(ReportFactory.buildTime);
    await tester.pumpAndSettle();
    expect(find.textContaining('report #1'), findsOneWidget);
    expect(find.textContaining('report #2'), findsOneWidget);
  });
}
