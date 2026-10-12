// ignore_for_file: deprecated_member_use_from_same_package

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the fixtures report their teardown, replaced by every `setUp`.
///
/// It used to be a list cleared per test, which is not the same thing:
/// teardown is not awaited, so a scope from the previous test can still be
/// releasing and append after the clear. A [Service] captures the recorder it
/// was *built* with, so a late report lands in the test it came from.
late DisposeRecorder recorder;

class Draft implements Disposable {
  Draft(this.label) : _recorder = recorder;

  final String label;
  final DisposeRecorder _recorder;
  var text = '';

  @override
  void dispose() => _recorder.record(label);
}

class DraftFactory implements CobaltFactory<Draft> {
  const DraftFactory(this.label);

  final String label;

  @override
  Draft create(CobaltResolver resolver) => Draft(label);
}

class PlainScreen extends CobaltScopedWidget {
  const PlainScreen({super.key});

  @override
  void registerScope(CobaltScope scope) =>
      scope.registerLazySingleton<Draft>(const DraftFactory('plain'));

  @override
  Widget buildScoped(BuildContext context) => Text(
    '${context.cobaltScope.name}/${context.cobalt<Draft>().label}',
    textDirection: TextDirection.ltr,
  );
}

class NamedScreen extends CobaltScopedWidget {
  const NamedScreen({super.key});

  @override
  String get scopeName => 'checkout';

  @override
  void registerScope(CobaltScope scope) =>
      scope.registerLazySingleton<Draft>(const DraftFactory('named'));

  @override
  Widget buildScoped(BuildContext context) =>
      Text(context.cobaltScope.name, textDirection: TextDirection.ltr);
}

class CounterScreen extends CobaltScopedStatefulWidget {
  const CounterScreen({super.key});

  @override
  void registerScope(CobaltScope scope) =>
      scope.registerLazySingleton<Draft>(const DraftFactory('counter'));

  @override
  CobaltScopedState<CounterScreen> createState() => CounterScreenState();
}

class CounterScreenState extends CobaltScopedState<CounterScreen> {
  var taps = 0;

  @override
  Widget buildScoped(BuildContext context) {
    final draft = context.cobalt<Draft>();
    return GestureDetector(
      onTap: () => setState(() => taps++),
      child: Text(
        '${context.cobaltScope.name} $taps ${identityHashCode(draft)}',
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

void main() {
  setUp(() => recorder = DisposeRecorder());

  Widget host(CobaltScope scope, Widget child) =>
      CobaltScopeProvider(scope: scope, child: child);

  group('CobaltScopedWidget', () {
    testWidgets('pushes a scope named after the widget', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(host(root, const PlainScreen()));
      await tester.pumpAndSettle();

      expect(find.text('PlainScreen/plain'), findsOneWidget);
      expect(root.children.single.name, 'PlainScreen');
    });

    testWidgets('an explicit scopeName wins', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(host(root, const NamedScreen()));
      await tester.pumpAndSettle();

      expect(find.text('checkout'), findsOneWidget);
    });

    testWidgets('unmounting disposes what the scope built', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(host(root, const PlainScreen()));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(root, const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(recorder.entries, ['plain']);
      expect(root.children, isEmpty);
    });
  });

  group('CobaltScopedStatefulWidget', () {
    testWidgets('setState rebuilds the content, not the scope', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(host(root, const CounterScreen()));
      await tester.pumpAndSettle();

      final before = tester.widget<Text>(find.byType(Text)).data!;
      expect(before, startsWith('CounterScreen 0 '));

      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      final after = tester.widget<Text>(find.byType(Text)).data!;
      expect(after, startsWith('CounterScreen 1 '));
      expect(
        after.split(' ').last,
        before.split(' ').last,
        reason: 'the same Draft instance, so the scope was not rebuilt',
      );
      expect(recorder.entries, isEmpty);
    });

    testWidgets('unmounting disposes the scope', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(host(root, const CounterScreen()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(root, const SizedBox.shrink()));
      await tester.pumpAndSettle();

      expect(recorder.entries, ['counter']);
    });
  });

  group('CobaltScopeWidget without a name', () {
    testWidgets('falls back to the builder type', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(
        host(
          root,
          CobaltScopeWidget(
            builder: const CobaltWidgetScopeBuilder(PlainScreen()),
            child: Builder(
              builder: (context) => Text(
                context.cobaltScope.name,
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CobaltWidgetScopeBuilder'), findsOneWidget);
    });
  });
}
