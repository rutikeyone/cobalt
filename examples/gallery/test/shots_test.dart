import 'dart:async';

import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/app/gallery_app.dart';
import 'package:gallery/app/shots.dart';
import 'package:gallery/features/hub/hub_screen.dart';

import 'support.dart';

void main() {
  Future<void> openShot(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      galleryHarness(home: Builder(builder: shots[name]!)),
    );
    // The inspector entry initialises its graph, opens a session and pushes
    // the inspector; the flow walks its visits a second apart.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
  }

  test('every screenshot in the README has a shot', () {
    expect(
      shots.keys,
      containsAll(['hub', 'tree', 'log', 'flow', 'flowlog', 'env']),
    );
  });

  testWidgets('hub is the gallery front page', (tester) async {
    await openShot(tester, 'hub');
    expect(find.byType(HubScreen), findsOneWidget);
  });

  for (final (name, tab) in [
    ('tree', CobaltInspectorTab.tree),
    ('log', CobaltInspectorTab.log),
  ]) {
    testWidgets('$name is the inspector on that tab, a session open', (
      tester,
    ) async {
      await openShot(tester, name);

      expect(find.byType(CobaltInspectorScreen), findsOneWidget);
      final controller = DefaultTabController.of(
        tester.element(find.byType(TabBar)),
      );
      expect(controller.index, tab.index);
      if (tab == CobaltInspectorTab.tree) {
        expect(find.text('session'), findsWidgets);
      }
    });
  }

  testWidgets('flow is order 1 at its payment step', (tester) async {
    await openShot(tester, 'flow');
    expect(find.byKey(const Key('payment-draft')), findsOneWidget);
    expect(find.byKey(const Key('switch-order')), findsOneWidget);
  });

  testWidgets('flowlog is home after two orders came and went', (tester) async {
    await openShot(tester, 'flowlog');
    expect(find.byKey(const Key('log-empty')), findsNothing);
    expect(find.textContaining('draft 1'), findsWidgets);
    expect(find.textContaining('draft 2'), findsWidgets);
  });

  testWidgets('env is the environments screen', (tester) async {
    await openShot(tester, 'env');
    expect(find.byKey(const Key('active-environment')), findsOneWidget);
  });

  group('the app', () {
    testWidgets('pushes a shot named by a link', (tester) async {
      await tester.pumpWidget(const GalleryApp());
      await tester.pumpAndSettle();

      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed('/shot/env'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active-environment')), findsOneWidget);
    });

    testWidgets('lands an unknown link on the hub', (tester) async {
      await tester.pumpWidget(const GalleryApp());
      await tester.pumpAndSettle();

      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed('/shot/nothing-here'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HubScreen), findsWidgets);
    });
  });
}
