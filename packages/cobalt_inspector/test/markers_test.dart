import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late CobaltInspectorLog log;
  late CobaltScope scope;

  setUp(() {
    clocksBuilt = 0;
    log = CobaltInspectorLog();
    scope =
        cobaltTestRoot(
            name: 'app',
            observers: [log],
            overrides: [CobaltOverride<Clock>.value(const Clock())],
          )
          ..registerLazySingleton<Clock>(
            FnFactory((_) {
              clocksBuilt++;
              return const Clock();
            }),
          )
          ..registerFactory<Api>(FnFactory((r) => Api(r.get<Clock>())))
          ..decorate<Api>(
            FnDecorator((inner, _) => inner),
            debugLabel: 'Retrying',
          )
          ..decorate<Api>(
            FnDecorator((inner, _) => inner),
            debugLabel: 'Logging',
          )
          ..registerParamFactory<Ticket, String>(
            FnParamFactory((_, id) => Ticket(id)),
          );
  });

  testWidgets('the tree marks what an override replaced and what is wrapped', (
    tester,
  ) async {
    await tester.pumpWidget(inspectorUnderTest(scope, log));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('overridden-Clock')), findsOneWidget);
    expect(find.byKey(const Key('decorated-Api')), findsOneWidget);
    expect(find.byKey(const Key('overridden-Api')), findsNothing);
    expect(find.byKey(const Key('decorated-Ticket')), findsNothing);
    expect(find.text('overridden'), findsOneWidget);
    expect(find.text('decorated'), findsOneWidget);
    expect(clocksBuilt, 0, reason: 'marking reads metadata, it builds nothing');
  });

  testWidgets('the detail sheet names the decorators, innermost first', (
    tester,
  ) async {
    await tester.pumpWidget(inspectorUnderTest(scope, log));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registration-Api')));
    await tester.pumpAndSettle();

    expect(find.text('Retrying → Logging'), findsOneWidget);
    expect(find.byKey(const Key('replaced-fact')), findsNothing);
  });

  testWidgets('the detail sheet says an override stands in', (tester) async {
    await tester.pumpWidget(inspectorUnderTest(scope, log));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registration-Clock')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('replaced-fact')), findsOneWidget);
    expect(find.byKey(const Key('decorated-fact')), findsNothing);
  });

  testWidgets('a child sees the markers of what it inherits', (tester) async {
    final child = scope.pushForTest('session');

    await tester.pumpWidget(inspectorUnderTest(child, log));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('overridden-Clock')),
      findsNWidgets(2),
      reason: 'the override belongs to the owner, and every node shows it',
    );
  });
}
