import 'dart:io';

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:cobalt_inspector/src/build_time.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class Slow {
  Slow();
}

class Quick {
  const Quick();
}

void main() {
  late CobaltInspectorLog log;

  setUp(() {
    log = CobaltInspectorLog();
    clocksBuilt = 0;
  });

  group('formatBuildTime', () {
    test('picks the unit a build is usually measured in', () {
      expect(formatBuildTime(const Duration(microseconds: 340)), '340 µs');
      expect(formatBuildTime(const Duration(microseconds: 12400)), '12.4 ms');
      expect(formatBuildTime(const Duration(milliseconds: 1250)), '1.25 s');
    });
  });

  /// One build long enough to count as slow, one that is not.
  CobaltScope slowAndQuick() => cobaltTestRoot(name: 'app', observers: [log])
    ..registerLazySingleton<Slow>(
      FnFactory((_) {
        sleep(const Duration(milliseconds: 20));
        return Slow();
      }),
    )
    ..registerLazySingleton<Quick>(FnFactory((_) => const Quick()));

  Future<void> openBuilt(WidgetTester tester, CobaltScope scope) async {
    await tester.pumpWidget(inspectorUnderTest(scope, log));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-created')));
    await tester.pumpAndSettle();
  }

  Text took(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key('took-$key')));

  group('what was built', () {
    testWidgets('shows how long each build took', (tester) async {
      final scope = slowAndQuick()
        ..get<Quick>()
        ..get<Slow>();
      await openBuilt(tester, scope);

      expect(
        took(tester, 'Quick').data,
        matches(RegExp(r'^\d+(\.\d)? (µs|ms)$')),
      );
      expect(took(tester, 'Slow').data, matches(RegExp(r'^\d+\.\d ms$')));
    });

    testWidgets('marks a build at least slowBuild long', (tester) async {
      final scope = slowAndQuick()
        ..get<Quick>()
        ..get<Slow>();
      await openBuilt(tester, scope);

      final palette = CobaltInspectorThemeData.of(ThemeData());
      expect(took(tester, 'Slow').style?.color, palette.warning);
      expect(took(tester, 'Quick').style?.color, palette.muted);
    });

    testWidgets('slowest first puts the longest build on top', (tester) async {
      final scope = slowAndQuick()
        ..get<Slow>()
        ..get<Quick>();
      await openBuilt(tester, scope);

      await tester.tap(find.byKey(const Key('group-slowest')));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('created-Slow'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('created-Quick'))).dy),
        reason: 'newest first would put Quick on top; slowest first does not',
      );
    });
  });

  group('a registration you tapped', () {
    testWidgets('shows how long its last build took', (tester) async {
      final scope = buildGraph(log);
      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registration-Clock')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('build-time-fact')),
        findsNothing,
        reason: 'nothing has built it yet',
      );

      await tester.tap(find.byKey(const Key('build-it')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('build-time-fact')), findsOneWidget);
      expect(find.text('Last build took'), findsOneWidget);
    });
  });
}
