// Not a test so much as a stage: `tool/screenshots.sh` runs this on the
// Simulator and takes a picture each time it announces a shot.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gallery/app/gallery_app.dart';
import 'package:gallery/app/shots.dart';
import 'package:integration_test/integration_test.dart';

/// Printed with a shot's name once it is on screen; the script watches for it.
const _marker = 'COBALT_SHOT';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('stages every shot', (tester) async {
    for (final name in shots.keys) {
      // A fresh app per shot, so none inherits another's log.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const GalleryApp());
      await tester.pump(const Duration(seconds: 1));

      // What a `cobaltgallery:///shot/<name>` link does.
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed('$shotPrefix$name'),
      );
      // Live frames: each pump waits for real. The flow shot walks three
      // routes a second apart; everything else is done well within.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      debugPrint('$_marker $name');
      // Held still while the picture is taken from outside.
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
  });
}
