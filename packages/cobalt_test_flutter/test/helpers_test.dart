// ignore_for_file: deprecated_member_use

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:cobalt_test_flutter/cobalt_test_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Clock {
  const Clock();
}

class ScreenState {
  const ScreenState();
}

/// A root whose phase one takes real time, the way a database open does.
///
/// The delay is what makes the second pump necessary: `settle` passes a
/// duration, which advances the fake clock, and a bare `pump()` does not.
final class SlowRoot implements CobaltScopeBuilder {
  const SlowRoot();

  @override
  void build(CobaltScope scope) => scope.registerAsyncSingleton<Clock>(
    AsyncFnFactory((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const Clock();
    }),
  );
}

/// A screen owning a scope of its own, published below the application's.
class OwningScreen extends CobaltScopedStatefulWidget {
  const OwningScreen({super.key});

  @override
  void registerScope(CobaltScope scope) => scope
      .registerLazySingleton<ScreenState>(ValueFactory(const ScreenState()));

  @override
  CobaltScopedState<OwningScreen> createState() => _OwningScreenState();
}

class _OwningScreenState extends CobaltScopedState<OwningScreen> {
  @override
  Widget buildScoped(BuildContext context) => const Scaffold();
}

Widget appWith(Widget child) => MaterialApp(
  home: CobaltAppScope(
    root: const SlowRoot(),
    rootName: 'app',
    // An indefinite animation: pumpAndSettle never returns while this is on
    // screen, which is the whole reason settle exists.
    loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
    child: child,
  ),
);

void main() {
  testWidgets('settle waits out a phase one that takes time', (tester) async {
    await tester.pumpWidget(appWith(const Scaffold()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason:
          'a bare pump does not advance the fake clock, so an initializer that '
          'awaits anything is still running — this is the frame a one-pump '
          'helper would hand back',
    );

    await settle(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the mounted root is the graph, not the nearest scope', (
    tester,
  ) async {
    await tester.pumpWidget(appWith(const OwningScreen()));
    await settle(tester);
    await settle(tester);

    final root = mountedRootScope(tester);

    expect(root.name, 'app');
    expect(
      root.isRegistered<Clock>(),
      isTrue,
      reason:
          'the screen publishes a provider of its own and it is the innermost '
          'one, so without climbing this answers with the screen and its '
          'ScreenState instead of the application and its Clock',
    );
    expect(root.children.single.isRegistered<ScreenState>(), isTrue);
  });
}
