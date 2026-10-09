# cobalt_test example

Build the graph once per test, override what the test needs, and check the whole thing resolves.

```dart
import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

void main() {
  late CobaltScope app;

  setUp(() async {
    app = await cobaltTestScope(root: const AppScope(), rootName: 'app');
  });

  test('the graph is complete', () async {
    await expectGraphResolves(app);
  });

  test('a fake clock reaches the greeter', () {
    final scope = app.pushForTest()
      ..registerSingleton<Clock>(FixedClock(DateTime.utc(2026)))
      ..registerLazySingleton<Greeter>(const GreeterFactory());

    expect(scope.get<Greeter>().greet(), contains('2026'));
  });
}
```

`Greeter` is re-registered on purpose: it is owned by the root, so without that line it would
resolve the real `Clock` and never see the fake. `scope.ownerOf<Greeter>()` is how you find that out
rather than guessing.

Checking the graph is terminal — it builds every lazy singleton — so keep it in its own test.

More patterns, with the tests that run them: [`examples/testing_patterns`](https://github.com/rutikeyone/cobalt/tree/main/examples/testing_patterns).
