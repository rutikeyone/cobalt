# cobalt_test_flutter example

```dart
import 'package:cobalt_test_flutter/cobalt_test_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the screen resolves what the graph registered', (tester) async {
    await tester.pumpWidget(const MyApp());
    // Not pumpAndSettle: the loading indicator schedules frames forever.
    await settle(tester);

    final app = mountedRootScope(tester);

    expect(app.isRegistered<NoteStore>(), isTrue);
    expect(find.text('0 notes'), findsOneWidget);
  });
}
```

A screen that owns a scope publishes a provider of its own, so `mountedRootScope` climbs past it —
what it returns is the application's graph, not the screen's.

More patterns, with the tests that run them: [`examples/testing_patterns`](https://github.com/rutikeyone/cobalt/tree/main/examples/testing_patterns).
