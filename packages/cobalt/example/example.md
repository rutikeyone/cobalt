# cobalt example

## A Flutter app

The smallest Cobalt app: two classes, one screen. Add the packages:

```bash
flutter pub add cobalt cobalt_flutter dev:cobalt_generator dev:build_runner
```

Replace `lib/main.dart`, then run `dart run build_runner build` and `flutter run`:

```dart
import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';

import 'cobalt.g.dart';

@cobaltInject
class Clock {
  Clock();

  DateTime now() => DateTime.now();
}

@cobaltInject
class Greeter {
  Greeter(this.clock);

  final Clock clock;

  String greet(String name) =>
      clock.now().hour < 12 ? 'Good morning, $name!' : 'Hello, $name!';
}

void main() => runApp(
  MaterialApp(
    builder: CobaltAppScope.builder(root: const CobaltRoot()),
    home: const HomeScreen(),
  ),
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final greeter = context.cobalt<Greeter>();
    return Scaffold(body: Center(child: Text(greeter.greet('Cobalt'))));
  }
}
```

`@cobaltInject` registers a class, and the generator wires `Greeter` to the `Clock` it asks for in
`lib/cobalt.g.dart`. The full app with its test: [`examples/hello`](https://github.com/rutikeyone/cobalt/tree/main/examples/hello).

## Without Flutter and the generator

The runtime on its own, in pure Dart: Manual Mode. The generator writes exactly this, using only
what is exported here.

```dart
import 'package:cobalt/cobalt.dart';

class Database {
  var isOpen = false;
}

final class DatabaseFactory implements CobaltFactory<Database> {
  const DatabaseFactory();

  @override
  Database create(CobaltResolver resolver) => Database();
}

class AppScope implements CobaltScopeBuilder {
  const AppScope();

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<Database>(const DatabaseFactory());
}

Future<void> main() async {
  final app = await CobaltApplication.start(
    root: const AppScope(),
    rootName: 'app',
  );

  print(app.get<Database>());

  // A child scope: everything built inside dies with it, in reverse order of
  // creation. This is what makes sign-out a single call.
  final session = app.push('session:42');
  await session.init();
  await session.dispose();

  await app.dispose();
}
```

More: [`examples/manual_mode`](https://github.com/rutikeyone/cobalt/tree/main/examples/manual_mode).
