import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Greeting {
  const Greeting(this.text);

  final String text;
}

class Session implements CobaltScopeBuilder {
  const Session(this.name);

  final String name;

  @override
  void build(CobaltScope scope) =>
      scope.registerSingleton<Greeting>(Greeting('Hello, $name'));
}

class _Greeter extends StatelessWidget {
  const _Greeter();

  @override
  Widget build(BuildContext context) =>
      Text(context.cobalt<Greeting>().text, textDirection: TextDirection.ltr);
}

void main() {
  late CobaltScope app;
  late CobaltScopeHolder holder;

  setUp(() {
    app = cobaltTestRoot(name: 'app');
    holder = CobaltScopeHolder(app);
  });

  tearDown(() => app.dispose());

  Future<void> pumpHeld(WidgetTester tester) => tester.pumpWidget(
    CobaltScopeProvider(
      scope: app,
      child: CobaltHeldScope(
        holder: holder,
        absent: const Text('signed out', textDirection: TextDirection.ltr),
        child: const _Greeter(),
      ),
    ),
  );

  testWidgets('shows absent while nothing is held', (tester) async {
    await pumpHeld(tester);

    expect(find.text('signed out'), findsOneWidget);
  });

  testWidgets('publishes the held scope to its child', (tester) async {
    await pumpHeld(tester);

    await tester.runAsync(
      () => holder.open('session:ada', const Session('Ada')),
    );
    await tester.pump();

    expect(find.text('Hello, Ada'), findsOneWidget);
  });

  testWidgets('follows the holder to the next scope and back to none', (
    tester,
  ) async {
    await pumpHeld(tester);

    await tester.runAsync(
      () => holder.open('session:ada', const Session('Ada')),
    );
    await tester.pump();
    await tester.runAsync(() => holder.open('session:bo', const Session('Bo')));
    await tester.pump();

    expect(find.text('Hello, Bo'), findsOneWidget);

    await tester.runAsync(holder.close);
    await tester.pump();

    expect(find.text('signed out'), findsOneWidget);
  });
}
