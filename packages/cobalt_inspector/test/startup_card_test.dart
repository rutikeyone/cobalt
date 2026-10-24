import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Config {}

class Catalog {
  Catalog(this.config);

  final Config config;
}

final class LoadSettings implements CobaltBootstrapStep {
  @override
  String get name => 'load-settings';

  @override
  Future<void> run() => Future<void>.delayed(const Duration(milliseconds: 5));
}

final class _Root implements CobaltScopeBuilder {
  const _Root();

  @override
  void build(CobaltScope scope) => scope
    ..registerAsyncSingleton<Config>(
      AsyncFnFactory((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return Config();
      }),
    )
    ..registerAsyncSingleton<Catalog>(
      AsyncFnFactory((resolver) async => Catalog(resolver.get<Config>())),
      dependsOn: {const CobaltKey(Config)},
    );
}

void main() {
  Future<void> openBuilt(
    WidgetTester tester,
    CobaltScope scope,
    CobaltInspectorLog log,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CobaltInspectorScreen(log: log, scope: scope),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-created')));
    await tester.pumpAndSettle();
  }

  testWidgets('the log keeps what the start spent its time on', (tester) async {
    final log = CobaltInspectorLog();
    final scope = await tester.runAsync(
      () => CobaltApplication.start(
        root: const _Root(),
        rootName: 'app',
        bootstrap: [LoadSettings()],
        observers: [log],
      ),
    );
    addTearDown(() => tester.runAsync(scope!.dispose));

    final startup = log.startup;
    expect(startup.bootstrap.map((step) => step.step), ['load-settings']);
    expect(
      startup.builds.map((build) => '${build.key}'),
      containsAll(['Config', 'Catalog']),
    );
  });

  testWidgets('the Built tab shows the start, folded until tapped', (
    tester,
  ) async {
    final log = CobaltInspectorLog();
    final scope = await tester.runAsync(
      () => CobaltApplication.start(
        root: const _Root(),
        rootName: 'app',
        bootstrap: [LoadSettings()],
        observers: [log],
      ),
    );
    addTearDown(() => tester.runAsync(scope!.dispose));

    await openBuilt(tester, scope!, log);

    expect(find.byKey(const Key('startup-card')), findsOneWidget);
    expect(find.textContaining('Startup: '), findsOneWidget);
    expect(find.byKey(const Key('startup-step-load-settings')), findsNothing);

    await tester.tap(find.byKey(const Key('startup-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startup-step-load-settings')), findsOneWidget);
    expect(find.text('Bootstrap steps'), findsOneWidget);
  });

  testWidgets('no card for a graph whose start the log did not see', (
    tester,
  ) async {
    final log = CobaltInspectorLog();
    final scope = cobaltTestRoot(name: 'app')
      ..registerLazySingleton<Config>(FnFactory((_) => Config()));
    addTearDown(scope.dispose);

    await openBuilt(tester, scope, log);

    expect(find.byKey(const Key('startup-card')), findsNothing);
  });

  testWidgets('fits a phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = CobaltInspectorLog();
    final scope = await tester.runAsync(
      () => CobaltApplication.start(
        root: const _Root(),
        rootName: 'app',
        bootstrap: [LoadSettings()],
        observers: [log],
      ),
    );
    addTearDown(() => tester.runAsync(scope!.dispose));

    await openBuilt(tester, scope!, log);
    await tester.tap(find.byKey(const Key('startup-toggle')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
