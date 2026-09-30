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

  testWidgets('the detail sheet names the class a registration builds', (
    tester,
  ) async {
    final described = cobaltTestRoot(name: 'described')
      ..registerLazySingleton<Clock>(const _LiveClockFactory());

    await tester.pumpWidget(inspectorUnderTest(described, log));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registration-Clock')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('implementation-fact')), findsOneWidget);
    expect(find.text('LiveClock'), findsOneWidget);
  });

  testWidgets('a factory that does not say shows no builds fact', (
    tester,
  ) async {
    await tester.pumpWidget(inspectorUnderTest(scope, log));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('registration-Api')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('implementation-fact')), findsNothing);
  });

  testWidgets('a scope with hooks lists them under its name', (tester) async {
    final hooked = cobaltTestRoot(name: 'hooked')
      ..hookAll<Api>(FnHook((_, _) {}), debugLabel: 'Audit')
      ..registerLazySingleton<Clock>(FnFactory((_) => const Clock()));

    await tester.pumpWidget(inspectorUnderTest(hooked, log));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hooks-hooked-0')), findsOneWidget);
    expect(find.text('hooks: Audit on Api'), findsOneWidget);
  });

  testWidgets('a scope without hooks shows no hooks line', (tester) async {
    await tester.pumpWidget(inspectorUnderTest(scope, log));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hooks-app-0')), findsNothing);
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

/// A factory that names what it builds, as generated ones do.
final class _LiveClockFactory
    implements CobaltFactory<Clock>, CobaltDescribedFactory {
  const _LiveClockFactory();

  @override
  String get implementation => 'LiveClock';

  @override
  Clock create(CobaltResolver resolver) => const Clock();
}
