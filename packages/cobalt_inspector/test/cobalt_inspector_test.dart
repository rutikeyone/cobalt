import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:flutter/material.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late CobaltInspectorLog log;
  late CobaltScope scope;

  setUp(() {
    clocksBuilt = 0;
    log = CobaltInspectorLog();
    scope = buildGraph(log);
  });

  group('the tree', () {
    testWidgets('shows the scope and what it registers', (tester) async {
      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scope-tree')), findsOneWidget);
      expect(find.text('app'), findsOneWidget);
      expect(find.byKey(const Key('registration-Clock')), findsOneWidget);
      expect(
        find.text('lifetime: lazySingleton'),
        findsNothing,
        reason: 'the lifetime is a badge now, not a sentence',
      );
      expect(find.text('lazySingleton'), findsWidgets);
    });

    testWidgets('names the owner of an inherited registration', (tester) async {
      final child = scope.pushForTest('session');

      await tester.pumpWidget(inspectorUnderTest(child, log));
      await tester.pumpAndSettle();

      expect(find.text('session'), findsOneWidget);

      // Every node opens by itself now; "collapse all" is the way back.
      expect(find.byKey(const Key('registration-Clock')), findsWidgets);
      expect(
        find.byIcon(Icons.subdirectory_arrow_right),
        findsWidgets,
        reason:
            'every registration the session sees but does not own is marked; '
            'the root owns all of its own and is marked nowhere',
      );

      await tester.tap(find.byKey(const Key('scope-session-1')));
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.subdirectory_arrow_right),
        findsNothing,
        reason: 'tapping the node folds its registrations away',
      );
    });

    /// The point of the whole design. `debugResolve` builds what it resolves,
    /// so an inspector that resolved rows in order to display them would
    /// create objects nobody asked for and log its own noise.
    testWidgets('renders without building anything', (tester) async {
      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();

      expect(clocksBuilt, 0);
      expect(log.created, isEmpty);
    });
  });

  testWidgets('opens from a pushed route, above the provider', (tester) async {
    await tester.pumpWidget(inspectorBehindAButton(scope, log));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-inspector')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scope-tree')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('a registration you tapped', () {
    Future<void> openDetail(WidgetTester tester) async {
      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registration-Clock')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows its facts without touching the graph', (tester) async {
      await openDetail(tester);

      expect(find.byKey(const Key('registration-detail')), findsOneWidget);
      expect(find.text('Owned by'), findsOneWidget);
      expect(clocksBuilt, 0);
    });

    testWidgets('builds only when asked, and says so', (tester) async {
      await openDetail(tester);
      await tester.tap(find.byKey(const Key('build-it')));
      await tester.pumpAndSettle();

      expect(clocksBuilt, 1);
      expect(find.byKey(const Key('built-value')), findsOneWidget);
      expect(log.created, hasLength(1));
    });

    testWidgets('builds a lazy async registration through getAsync', (
      tester,
    ) async {
      scope.registerLazyAsyncSingleton<Warehouse>(
        AsyncFnFactory((_) async => Warehouse()),
      );
      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();

      expect(find.text('lazyAsyncSingleton'), findsWidgets);

      await tester.tap(find.byKey(const Key('registration-Warehouse')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('build-it')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('built-value')), findsOneWidget);
      expect(find.byKey(const Key('build-failed')), findsNothing);
      expect(scope.get<Warehouse>(), isA<Warehouse>());
    });

    testWidgets('offers no build for a parameterized factory', (tester) async {
      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('registration-Ticket')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('not-buildable')), findsOneWidget);
      expect(find.byKey(const Key('build-it')), findsNothing);
    });
  });

  group('what was built', () {
    testWidgets('is empty until something is', (tester) async {
      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-created')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nothing-built')), findsOneWidget);
    });

    testWidgets('reports the lifetime of each instance', (tester) async {
      scope.get<Clock>();
      scope.get<Api>();

      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-created')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('created-Clock')), findsOneWidget);
      expect(
        find.textContaining('lazySingleton'),
        findsWidgets,
        reason: 'the lifetime is the fact the log was extended to carry',
      );
      expect(find.textContaining('transient'), findsWidgets);
    });
  });

  group('the log', () {
    testWidgets('filters by event kind', (tester) async {
      scope.get<Clock>();

      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-log')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('event-log')), findsOneWidget);

      // Filtering is by family now: thirteen kinds is too many to scan, and
      // the four families are the division the talker adapter already makes.
      await tester.tap(find.byKey(const Key('filter-failure')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('no-events')), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter-instance')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('event-log')), findsOneWidget);
    });

    testWidgets('clearing empties it', (tester) async {
      scope.get<Clock>();

      await tester.pumpWidget(inspectorUnderTest(scope, log));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clear-log')));
      await tester.pumpAndSettle();

      expect(log.records, isEmpty);
    });
  });
}

final class Warehouse {}
