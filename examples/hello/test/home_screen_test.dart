import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hello/cobalt.g.dart';
import 'package:hello/main.dart';

class FixedClock implements Clock {
  FixedClock(this.time);

  final DateTime time;

  @override
  DateTime now() => time;
}

void main() {
  Future<void> pumpAt(WidgetTester tester, DateTime time) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: CobaltAppScope.builder(
          root: const CobaltRoot(),
          overrides: () => [CobaltOverride<Clock>.value(FixedClock(time))],
        ),
        home: const HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('greets in the morning', (tester) async {
    await pumpAt(tester, DateTime(2026, 10, 7, 9));

    expect(find.text('Good morning, Cobalt!'), findsOneWidget);
  });

  testWidgets('greets later in the day', (tester) async {
    await pumpAt(tester, DateTime(2026, 10, 7, 15));

    expect(find.text('Hello, Cobalt!'), findsOneWidget);
  });
}
