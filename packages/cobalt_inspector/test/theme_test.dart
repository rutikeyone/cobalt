import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  group('the palette', () {
    testWidgets('is derived from the host theme when nobody sets one', (
      tester,
    ) async {
      final host = ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      );
      late CobaltInspectorThemeData palette;

      await tester.pumpWidget(
        MaterialApp(
          theme: host,
          home: Builder(
            builder: (context) {
              palette = CobaltInspectorTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(palette.background, host.colorScheme.surface);
      expect(palette.accent, host.colorScheme.primary);
      expect(palette.failure, host.colorScheme.error);
    });

    testWidgets('an inherited one reaches a descendant', (tester) async {
      const mine = CobaltInspectorThemeData(
        background: Color(0xFF101010),
        surface: Color(0xFF202020),
        onSurface: Color(0xFFEEEEEE),
        muted: Color(0xFF999999),
        outline: Color(0xFF333333),
        accent: Color(0xFF00E5FF),
        scope: Color(0xFF00E5FF),
        startup: Color(0xFF76FF03),
        instance: Color(0xFF999999),
        failure: Color(0xFFFF5252),
        warning: Color(0xFFFFC107),
      );
      late CobaltInspectorThemeData seen;

      await tester.pumpWidget(
        MaterialApp(
          home: CobaltInspectorTheme(
            data: mine,
            child: Builder(
              builder: (context) {
                seen = CobaltInspectorTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(seen, mine);
    });

    /// Fourteen kinds, four families: a kind added without a colour should
    /// fail here rather than paint itself grey in a corner of a screen.
    test('every event kind lands in a family', () {
      for (final kind in CobaltEventKind.values) {
        expect(
          CobaltInspectorFamily.values,
          contains(CobaltInspectorFamily.of(kind)),
          reason: '$kind',
        );
      }
    });

    test('every family names the title the talker adapter writes', () {
      expect(CobaltInspectorFamily.values.map((f) => f.talkerTitle).toSet(), {
        'cobalt-scope',
        'cobalt-startup',
        'cobalt-instance',
        'cobalt-failure',
      });
    });

    /// The three maps are read per entry, which is the whole point of them:
    /// naming one lifetime must not silently un-derive the other four.
    group('what is derived can be named instead', () {
      test('a named lifetime wins and the rest keep deriving', () {
        final base = CobaltInspectorThemeData.of(ThemeData.dark());
        final mine = base.copyWith(
          lifetimeColors: const {
            CobaltRegistrationKind.singleton: Color(0xFFAA0000),
          },
        );

        expect(
          mine.colorOfLifetime(CobaltRegistrationKind.singleton),
          const Color(0xFFAA0000),
        );
        expect(
          mine.colorOfLifetime(CobaltRegistrationKind.lazySingleton),
          base.colorOfLifetime(CobaltRegistrationKind.lazySingleton),
          reason: 'the four nobody named still derive',
        );
      });

      test('a named level wins and the rest keep deriving', () {
        final base = CobaltInspectorThemeData.of(ThemeData.dark());
        final mine = base.copyWith(
          levelColors: const {CobaltLogLevel.trace: Color(0xFF00BB00)},
        );

        expect(
          mine.colorOfLevel(CobaltLogLevel.trace),
          const Color(0xFF00BB00),
        );
        expect(
          mine.colorOfLevel(CobaltLogLevel.error),
          base.failure,
          reason: 'error still derives from the failure colour',
        );
      });

      test('a named family icon wins and the rest keep deriving', () {
        final base = CobaltInspectorThemeData.of(ThemeData.dark());
        final mine = base.copyWith(
          familyIcons: const {CobaltInspectorFamily.scope: Icons.star},
        );

        expect(mine.iconOfFamily(CobaltInspectorFamily.scope), Icons.star);
        expect(
          mine.iconOfFamily(CobaltInspectorFamily.failure),
          base.iconOfFamily(CobaltInspectorFamily.failure),
        );
      });
    });

    /// A warning is not a startup event, and used to be painted as one.
    test('warning has a colour of its own, not the startup green', () {
      final palette = CobaltInspectorThemeData.of(ThemeData.dark());

      expect(palette.colorOfLevel(CobaltLogLevel.warning), palette.warning);
      expect(palette.warning, isNot(palette.startup));
    });

    test('two palettes differing only in a map are not equal', () {
      final base = CobaltInspectorThemeData.of(ThemeData.dark());
      final mine = base.copyWith(
        lifetimeColors: const {
          CobaltRegistrationKind.transient: Color(0xFF010203),
        },
      );

      expect(mine, isNot(base));
      expect(mine.hashCode, isNot(base.hashCode));
      expect(
        mine,
        base.copyWith(
          lifetimeColors: const {
            CobaltRegistrationKind.transient: Color(0xFF010203),
          },
        ),
        reason: 'equal maps make equal palettes, whatever instance they are',
      );
    });

    test('every lifetime and level has a colour', () {
      final palette = CobaltInspectorThemeData.of(ThemeData.light());
      for (final kind in CobaltRegistrationKind.values) {
        expect(() => palette.colorOfLifetime(kind), returnsNormally);
      }
      for (final level in CobaltLogLevel.values) {
        expect(() => palette.colorOfLevel(level), returnsNormally);
      }
    });

    /// A palette nothing reads is a value, not a theme. These mount the real
    /// screens and read the colour off the widget that draws it.
    group('what is named reaches the screen', () {
      late CobaltInspectorLog log;
      late CobaltScope scope;

      setUp(() {
        clocksBuilt = 0;
        log = CobaltInspectorLog();
        scope = buildGraph(log);
        addTearDown(log.dispose);
      });

      testWidgets('a named lifetime paints the badge in the tree', (
        tester,
      ) async {
        await tester.pumpWidget(
          CobaltInspectorTheme(
            data: CobaltInspectorThemeData.of(ThemeData.dark()).copyWith(
              lifetimeColors: const {
                CobaltRegistrationKind.lazySingleton: Color(0xFFAB1234),
              },
            ),
            child: inspectorUnderTest(scope, log),
          ),
        );
        await tester.pump();

        final badge = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('registration-Clock')),
            matching: find.text('lazySingleton'),
          ),
        );

        expect(badge.style?.color, const Color(0xFFAB1234));
      });

      /// The alphas default to what used to be written into four files, so a
      /// test that leaves them alone cannot tell whether they are read at all.
      testWidgets('a named tint alpha is the one the badge is filled with', (
        tester,
      ) async {
        await tester.pumpWidget(
          CobaltInspectorTheme(
            data: CobaltInspectorThemeData.of(
              ThemeData.dark(),
            ).copyWith(tintAlpha: 0.5, borderAlpha: 0.9),
            child: inspectorUnderTest(scope, log),
          ),
        );
        await tester.pumpAndSettle();

        final badge = tester.widget<Container>(
          find
              .descendant(
                of: find.byKey(const Key('registration-Clock')),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = badge.decoration! as BoxDecoration;

        expect(decoration.color!.a, closeTo(0.5, 0.01));
        expect(decoration.border!.top.color.a, closeTo(0.9, 0.01));
      });

      testWidgets('a named family icon is the one the log marks rows with', (
        tester,
      ) async {
        // Building one gives the log an instance-family row to mark.
        scope.get<Clock>();

        await tester.pumpWidget(
          CobaltInspectorTheme(
            data: CobaltInspectorThemeData.of(ThemeData.dark()).copyWith(
              familyIcons: const {CobaltInspectorFamily.instance: Icons.star},
            ),
            child: inspectorUnderTest(scope, log),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tab-log')));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.star), findsWidgets);
        expect(find.byIcon(Icons.widgets_outlined), findsNothing);
      });
    });

    test('copyWith replaces only what it is given', () {
      final base = CobaltInspectorThemeData.of(ThemeData.light());
      final changed = base.copyWith(failure: const Color(0xFF123456));

      expect(changed.failure, const Color(0xFF123456));
      expect(changed.accent, base.accent);
      expect(changed == base, isFalse);
    });
  });
}
