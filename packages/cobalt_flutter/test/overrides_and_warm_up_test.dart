import 'dart:async';

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Greeting implements Disposable {
  Greeting(this.text);

  final String text;
  var isClosed = false;

  @override
  void dispose() => isClosed = true;
}

class Engine {}

class GreetingScope implements CobaltScopeBuilder {
  const GreetingScope();

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<Greeting>(FnFactory((_) => Greeting('real')));
}

class BrokenScope implements CobaltScopeBuilder {
  const BrokenScope();

  @override
  void build(CobaltScope scope) {
    scope.registerLazySingleton<Greeting>(FnFactory((_) => Greeting('real')));
    throw StateError('builder failed');
  }
}

class GreetingText extends StatelessWidget {
  const GreetingText({super.key});

  @override
  Widget build(BuildContext context) =>
      Text(context.cobalt<Greeting>().text, textDirection: TextDirection.ltr);
}

class OverriddenScreen extends CobaltScopedWidget {
  const OverriddenScreen({super.key});

  @override
  List<CobaltOverride<Object>> Function()? get overrides =>
      () => [CobaltOverride<Greeting>.value(Greeting('screen double'))];

  @override
  void registerScope(CobaltScope scope) => const GreetingScope().build(scope);

  @override
  Widget buildScoped(BuildContext context) => const GreetingText();
}

class OverriddenStatefulScreen extends CobaltScopedStatefulWidget {
  const OverriddenStatefulScreen({super.key});

  @override
  List<CobaltOverride<Object>> Function()? get overrides =>
      () => [CobaltOverride<Greeting>.value(Greeting('stateful double'))];

  @override
  void registerScope(CobaltScope scope) => const GreetingScope().build(scope);

  @override
  CobaltScopedState<OverriddenStatefulScreen> createState() => _State();
}

class _State extends CobaltScopedState<OverriddenStatefulScreen> {
  @override
  Widget buildScoped(BuildContext context) => const GreetingText();
}

Widget errorText(BuildContext context, Object error) =>
    Text('failed: $error', textDirection: TextDirection.ltr);

void main() {
  group('overrides on a widget-owned scope', () {
    testWidgets('replace what the builder registers', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(
        CobaltScopeProvider(
          scope: root,
          child: CobaltScopeWidget(
            name: 'screen',
            builder: const GreetingScope(),
            overrides: () => [
              CobaltOverride<Greeting>.value(Greeting('double')),
            ],
            child: const GreetingText(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('double'), findsOneWidget);
      expect(root.children.single.overriddenKeys, [const CobaltKey(Greeting)]);
    });

    testWidgets('a remount gets a fresh value, not the one it closed', (
      tester,
    ) async {
      final root = cobaltTestRoot(name: 'app');
      final handed = <Greeting>[];
      Widget screen() => CobaltScopeProvider(
        scope: root,
        child: CobaltScopeWidget(
          name: 'screen',
          builder: const GreetingScope(),
          overrides: () {
            final double = Greeting('double ${handed.length}');
            handed.add(double);
            return [CobaltOverride<Greeting>.value(double)];
          },
          child: const GreetingText(),
        ),
      );

      await tester.pumpWidget(screen());
      await tester.pump();
      await tester.pumpWidget(
        CobaltScopeProvider(scope: root, child: const SizedBox.shrink()),
      );
      await tester.pump();
      await tester.pumpWidget(screen());
      await tester.pump();

      expect(handed, hasLength(2));
      expect(handed.first.isClosed, isTrue);
      expect(handed.last.isClosed, isFalse);
      expect(find.text('double 1'), findsOneWidget);
    });

    testWidgets('one for a key an ancestor owns fails, naming the owner', (
      tester,
    ) async {
      final root = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Greeting>(FnFactory((_) => Greeting('root')));

      await tester.pumpWidget(
        CobaltScopeProvider(
          scope: root,
          child: CobaltScopeWidget(
            name: 'screen',
            builder: const _Empty(),
            overrides: () => [CobaltOverride<Greeting>.value(Greeting('x'))],
            errorBuilder: errorText,
            child: const GreetingText(),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Move the override to "app"'), findsOneWidget);
      expect(
        root.children,
        isEmpty,
        reason: 'the child that was pushed is disposed, not left in the tree',
      );
    });

    testWidgets('a builder that throws leaves no scope behind', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(
        CobaltScopeProvider(
          scope: root,
          child: const CobaltScopeWidget(
            name: 'screen',
            builder: BrokenScope(),
            errorBuilder: errorText,
            child: GreetingText(),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('builder failed'), findsOneWidget);
      expect(root.children, isEmpty);
    });

    testWidgets('a scoped widget declares them with a getter', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(
        CobaltScopeProvider(scope: root, child: const OverriddenScreen()),
      );
      await tester.pump();

      expect(find.text('screen double'), findsOneWidget);
    });

    testWidgets('so does a scoped stateful widget', (tester) async {
      final root = cobaltTestRoot(name: 'app');

      await tester.pumpWidget(
        CobaltScopeProvider(
          scope: root,
          child: const OverriddenStatefulScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('stateful double'), findsOneWidget);
    });
  });

  group('warming up from CobaltAppScope', () {
    testWidgets('the app is shown before the warm-up finishes', (tester) async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      var built = 0;

      await tester.pumpWidget(
        CobaltAppScope(
          root: _LazyEngine(() async {
            built++;
            await gate.future;
            return Engine();
          }),
          warmUp: const [CobaltKey(Engine)],
          loading: const Text('loading', textDirection: TextDirection.ltr),
          child: const Text('app', textDirection: TextDirection.ltr),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('app'), findsOneWidget);
      expect(built, 1, reason: 'the build started without anyone asking');

      gate.complete();
      await tester.pump();
      final scope = CobaltScopeProvider.of(tester.element(find.text('app')));
      expect(scope.get<Engine>(), isA<Engine>());
      expect(built, 1);
    });

    testWidgets('a failed warm-up is reported, the app keeps running', (
      tester,
    ) async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        CobaltAppScope(
          root: _LazyEngine(() async => throw StateError('no engine')),
          warmUp: const [CobaltKey(Engine)],
          child: const Text('app', textDirection: TextDirection.ltr),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('app'), findsOneWidget);
      expect(reported.single.exception, isA<CobaltWarmUpError>());
      expect(
        reported.single.context.toString(),
        contains('warming up the root scope'),
      );
    });
  });
}

class _Empty implements CobaltScopeBuilder {
  const _Empty();

  @override
  void build(CobaltScope scope) {}
}

class _LazyEngine implements CobaltScopeBuilder {
  const _LazyEngine(this.create);

  final Future<Engine> Function() create;

  @override
  void build(CobaltScope scope) =>
      scope.registerLazyAsyncSingleton<Engine>(AsyncFnFactory((_) => create()));
}
