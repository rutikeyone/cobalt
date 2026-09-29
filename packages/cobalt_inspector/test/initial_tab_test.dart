import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late CobaltInspectorLog log;

  setUp(() {
    log = CobaltInspectorLog();
    clocksBuilt = 0;
  });

  testWidgets('opens on the tree unless told otherwise', (tester) async {
    await tester.pumpWidget(inspectorUnderTest(buildGraph(log), log));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scope-tree')), findsOneWidget);
  });

  for (final (tab, key) in [
    (CobaltInspectorTab.built, 'nothing-built'),
    (CobaltInspectorTab.log, 'tab-log'),
  ]) {
    testWidgets('opens on ${tab.name} when asked', (tester) async {
      final scope = buildGraph(log);
      await tester.pumpWidget(
        MaterialApp(
          home: CobaltInspectorScreen(log: log, scope: scope, initialTab: tab),
        ),
      );
      await tester.pumpAndSettle();

      final controller = DefaultTabController.of(
        tester.element(find.byType(TabBar)),
      );
      expect(controller.index, tab.index);
      expect(find.byKey(Key(key)), findsWidgets);
    });
  }
}
