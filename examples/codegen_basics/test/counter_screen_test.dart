import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:codegen_basics/cobalt.g.dart';
import 'package:codegen_basics/counter_screen.dart';
import 'package:codegen_basics/greeting.dart';
import 'package:codegen_basics/l10n/codegen_basics_l10n.dart';
import 'package:codegen_basics/leaderboard.dart';
import 'package:codegen_basics/services.dart';
import 'package:codegen_basics/tracked_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The delegates the screen needs, in the order an app installs them.
///
/// The example is a library the gallery mounts, so in the running app these
/// are registered there; a test mounting the screen on its own has to supply
/// them itself.
const _delegates = [
  CodegenBasicsL10n.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  /// The screen is where the generated container meets widgets, and where a
  /// parameterized registration is actually resolved. It was written and run
  /// by nothing.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: _delegates,
        supportedLocales: CodegenBasicsL10n.supportedLocales,
        home: CobaltAppScope(
          root: $CobaltRootScope(),
          rootName: $cobaltRootScopeName,
          child: CounterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the screen resolves its bloc from the generated graph', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('0'), findsOneWidget);
    expect(find.text('environment: test'), findsOneWidget);

    await tester.tap(find.text('increment'));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('the bloc writes through the generated decorator', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('increment'));
    await tester.pump();

    final root = CobaltScopeProvider.of(
      tester.element(find.byType(CounterScreen)),
    ).root;
    final repository = root.get<Repository>();

    expect(repository, isA<TrackedRepository>());
    expect(
      (repository as TrackedRepository).writes,
      1,
      reason: 'the injected field received the wrapper, not the class itself',
    );
  });

  test('startup does not build the leaderboard', () async {
    final scope = await $startCobalt();
    addTearDown(scope.dispose);

    expect(
      () => scope.get<Leaderboard>(),
      throwsA(isA<CobaltLazyAsyncError>()),
      reason: 'it is lazy: the first getAsync builds it, not init()',
    );
  });

  testWidgets('the screen that shows the leaderboard builds it', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('leaderboard ready: 3 entries'), findsOneWidget);
  });

  testWidgets('a parameterized registration is resolved with its record', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(
      find.text('hello Cobalt from test'),
      findsOneWidget,
      reason:
          'the config came from the graph, the name and the flag from the '
          'call site',
    );
  });

  testWidgets('the record is what the call site passes, not a fixed value', (
    tester,
  ) async {
    late Greeting loud;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: _delegates,
        supportedLocales: CodegenBasicsL10n.supportedLocales,
        home: CobaltAppScope(
          root: const $CobaltRootScope(),
          rootName: $cobaltRootScopeName,
          child: Builder(
            builder: (context) {
              loud = context.cobaltWithParam<Greeting, $GreetingArgs>((
                name: 'World',
                loud: true,
              ));
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loud.name, 'World', reason: 'the call site supplied this half');
    expect(loud.environment, 'test', reason: 'and the graph supplied this one');
    expect(
      loud.render('hello ${loud.name} from ${loud.environment}'),
      'HELLO WORLD FROM TEST',
      reason: 'loud is what render still decides; the words are the screen\'s',
    );
  });
}
