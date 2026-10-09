import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/app/gallery_app.dart';
import 'package:gallery/features/hub/example_card.dart';
import 'package:gallery/features/hub/hub_screen.dart';
import 'package:gallery/l10n/gallery_l10n.dart';
import 'package:integration_test/integration_test.dart';

const _marker = 'COBALT_TOUR';

Future<void> _hold(WidgetTester tester, Duration duration) async {
  final frames = duration.inMilliseconds ~/ 50;
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walks the quick tour', (tester) async {
    await tester.pumpWidget(const GalleryApp());
    await _hold(tester, const Duration(seconds: 2));

    debugPrint('$_marker ready');
    await _hold(tester, const Duration(milliseconds: 2500));

    final l10n = GalleryL10n.of(tester.element(find.byType(HubScreen)));
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    unawaited(
      position.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeInOut,
      ),
    );
    await _hold(tester, const Duration(milliseconds: 1700));

    await tester.tap(find.widgetWithText(ExampleCard, l10n.inspectorTitle));
    await _hold(tester, const Duration(milliseconds: 1600));

    await tester.tap(find.widgetWithText(FilledButton, l10n.openExample));
    await _hold(tester, const Duration(milliseconds: 1400));

    await tester.tap(find.byKey(const Key('open-session')));
    await _hold(tester, const Duration(milliseconds: 1000));

    await tester.tap(find.byKey(const Key('open-inspector')));
    await _hold(tester, const Duration(milliseconds: 3000));

    debugPrint('$_marker done');
    await _hold(tester, const Duration(seconds: 2));
  });
}
