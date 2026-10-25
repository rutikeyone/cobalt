import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class User {
  const User(this.name);

  final String name;
}

class Session {}

final class SessionScope extends CobaltChildScopeBuilder {
  const SessionScope(this.user);

  final User user;

  @override
  Type get marker => Session;

  @override
  bool operator ==(Object other) => other is SessionScope && other.user == user;

  @override
  int get hashCode => Object.hashAll([SessionScope, user]);

  @override
  void build(CobaltScope scope) => scope.registerSingleton<User>(user);
}

final class HandWrittenScope implements CobaltScopeBuilder {
  HandWrittenScope(this.user);

  final User user;

  @override
  void build(CobaltScope scope) => scope.registerSingleton<User>(user);
}

class _ShowUser extends StatelessWidget {
  const _ShowUser();

  @override
  Widget build(BuildContext context) =>
      Text(context.cobalt<User>().name, textDirection: TextDirection.ltr);
}

void main() {
  const ada = User('ada');
  const bob = User('bob');

  Future<CobaltScope> show(
    WidgetTester tester,
    CobaltScope app,
    CobaltScopeBuilder builder,
  ) async {
    await tester.pumpWidget(
      CobaltScopeProvider(
        scope: app,
        child: CobaltScopeWidget(
          name: 'session',
          builder: builder,
          child: const _ShowUser(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return app.children.single;
  }

  testWidgets('a generated builder with other values opens a new scope', (
    tester,
  ) async {
    final app = cobaltTestRoot(name: 'app');

    final first = await show(tester, app, const SessionScope(ada));
    expect(find.text('ada'), findsOneWidget);

    final second = await show(tester, app, const SessionScope(bob));
    expect(find.text('bob'), findsOneWidget);
    expect(second, isNot(same(first)));
    expect(first.state, CobaltScopeState.disposed);
  });

  testWidgets('an equal generated builder keeps the scope', (tester) async {
    final app = cobaltTestRoot(name: 'app');

    final first = await show(tester, app, SessionScope(ada));
    final again = await show(tester, app, SessionScope(ada));

    expect(again, same(first));
    expect(first.state, CobaltScopeState.active);
  });

  testWidgets('a hand-written builder is read once', (tester) async {
    final app = cobaltTestRoot(name: 'app');

    final first = await show(tester, app, HandWrittenScope(ada));
    final again = await show(tester, app, HandWrittenScope(bob));

    expect(again, same(first));
    expect(find.text('ada'), findsOneWidget);
  });
}
