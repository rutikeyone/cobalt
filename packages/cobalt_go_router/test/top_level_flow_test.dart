import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support.dart';

/// A flow whose screens share no path prefix.
///
/// `ShellRoute` has no `path` of its own, so its children keep their absolute,
/// top-level URLs. `/cart`, `/checkout` and `/payment` stay exactly what they
/// were, and still share one scope for as long as the user is on any of them.
GoRouter checkoutRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('home')),
    ),
    CobaltShellRoute(
      name: 'checkout',
      scope: (_) => const TrackedScope('cart-draft'),
      routes: [
        GoRoute(path: '/cart', builder: (_, _) => const Probe()),
        GoRoute(path: '/checkout', builder: (_, _) => const Probe()),
        GoRoute(path: '/payment', builder: (_, _) => const Probe()),
      ],
    ),
  ],
);

void main() {
  late CobaltScope root;
  late GoRouter router;

  setUp(() {
    recorder = DisposeRecorder();
    root = cobaltTestRoot(name: 'app');
  });

  tearDown(() => router.dispose());

  Future<void> start(WidgetTester tester, {String initial = '/'}) async {
    router = checkoutRouter(initialLocation: initial);
    await tester.pumpWidget(app(root, router));
    await settle(tester);
  }

  Future<void> open(WidgetTester tester, String location) async {
    router.go(location);
    await settle(tester);
  }

  testWidgets('three top-level routes share one scope while it is open', (
    tester,
  ) async {
    await start(tester);
    await open(tester, '/cart');
    final first = textStartingWith('instance:');

    await open(tester, '/checkout');
    expect(textStartingWith('instance:'), first);

    await open(tester, '/payment');
    expect(textStartingWith('instance:'), first);
    expect(recorder.entries, isEmpty);
    expect(root.children.single.name, 'checkout');
  });

  testWidgets('leaving for a route outside the flow disposes it', (
    tester,
  ) async {
    await start(tester);
    await open(tester, '/cart');
    await open(tester, '/payment');

    await open(tester, '/');

    expect(recorder.entries, ['cart-draft']);
    expect(root.children, isEmpty);
  });

  testWidgets('a deep link into the middle of the flow raises its scope', (
    tester,
  ) async {
    await start(tester, initial: '/payment');

    expect(find.text('scope:checkout'), findsOneWidget);
    expect(find.text('label:cart-draft'), findsOneWidget);
    expect(root.children.single.name, 'checkout');
  });

  testWidgets('the URLs are the ones declared, with no shell prefix', (
    tester,
  ) async {
    await start(tester);
    await open(tester, '/checkout');

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/checkout',
    );
  });
}
