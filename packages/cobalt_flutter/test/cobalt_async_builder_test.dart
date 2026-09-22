import 'dart:async';

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final class Engine {
  Engine(this.label);

  final String label;
}

Widget _mount(CobaltScope scope, Widget child) => CobaltScopeProvider(
  scope: scope,
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

CobaltAsyncBuilder<Engine> _engineView({
  Widget Function(BuildContext, Object, VoidCallback)? errorBuilder,
}) => CobaltAsyncBuilder<Engine>(
  loading: const Text('loading'),
  errorBuilder: errorBuilder,
  builder: (context, engine) => Text('engine ${engine.label}'),
);

void main() {
  testWidgets('shows loading, then builds from the resolved instance', (
    tester,
  ) async {
    final gate = Completer<void>();
    final scope = cobaltTestRoot()
      ..registerLazyAsyncSingleton<Engine>(
        AsyncFnFactory((_) async {
          await gate.future;
          return Engine('ready');
        }),
      );

    await tester.pumpWidget(_mount(scope, _engineView()));
    expect(find.text('loading'), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('engine ready'), findsOneWidget);
  });

  testWidgets('a parent rebuild does not start the build again', (
    tester,
  ) async {
    var builds = 0;
    final scope = cobaltTestRoot()
      ..registerLazyAsyncSingleton<Engine>(
        AsyncFnFactory((_) async {
          builds++;
          return Engine('once');
        }),
      );

    await tester.pumpWidget(_mount(scope, _engineView()));
    await tester.pumpWidget(_mount(scope, _engineView()));
    await tester.pump();

    expect(builds, 1);
    expect(find.text('engine once'), findsOneWidget);
  });

  testWidgets('a parent rebuild does not retry a failed build by itself', (
    tester,
  ) async {
    var attempts = 0;
    final scope = cobaltTestRoot()
      ..registerLazyAsyncSingleton<Engine>(
        AsyncFnFactory((_) async {
          attempts++;
          throw StateError('offline');
        }),
      );
    Widget view() => _mount(
      scope,
      _engineView(
        errorBuilder: (context, error, retry) => const Text('failed'),
      ),
    );

    await tester.pumpWidget(view());
    await tester.pump();
    await tester.pumpWidget(view());
    await tester.pump();

    expect(find.text('failed'), findsOneWidget);
    expect(attempts, 1);
  });

  testWidgets('an instance already built renders without a loading frame', (
    tester,
  ) async {
    final scope = cobaltTestRoot()
      ..registerLazyAsyncSingleton<Engine>(
        AsyncFnFactory((_) async => Engine('warm')),
      );
    await tester.runAsync(() => scope.getAsync<Engine>());

    await tester.pumpWidget(_mount(scope, _engineView()));

    expect(find.text('loading'), findsNothing);
    expect(find.text('engine warm'), findsOneWidget);
  });

  testWidgets('a failure goes to errorBuilder, and retry builds again', (
    tester,
  ) async {
    var attempts = 0;
    final scope = cobaltTestRoot()
      ..registerLazyAsyncSingleton<Engine>(
        AsyncFnFactory((_) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
          return Engine('second try');
        }),
      );

    await tester.pumpWidget(
      _mount(
        scope,
        _engineView(
          errorBuilder: (context, error, retry) =>
              GestureDetector(onTap: retry, child: const Text('retry')),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('retry'), findsOneWidget);

    await tester.tap(find.text('retry'));
    await tester.pump();
    await tester.pump();

    expect(attempts, 2);
    expect(find.text('engine second try'), findsOneWidget);
  });

  testWidgets('without errorBuilder the failure is rethrown during build', (
    tester,
  ) async {
    final scope = cobaltTestRoot()
      ..registerLazyAsyncSingleton<Engine>(
        AsyncFnFactory((_) async => throw StateError('offline')),
      );

    await tester.pumpWidget(_mount(scope, _engineView()));
    await tester.pump();

    expect(tester.takeException(), isA<StateError>());
  });

  testWidgets('context.cobaltAsync resolves from the nearest scope', (
    tester,
  ) async {
    final scope = cobaltTestRoot()
      ..registerLazyAsyncSingleton<Engine>(
        AsyncFnFactory((_) async => Engine('through context')),
      );
    late Future<Engine> resolved;

    await tester.pumpWidget(
      _mount(
        scope,
        Builder(
          builder: (context) {
            resolved = context.cobaltAsync<Engine>();
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect((await tester.runAsync(() => resolved))!.label, 'through context');
  });
}
