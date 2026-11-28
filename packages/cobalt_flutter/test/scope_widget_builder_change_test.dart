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
  List<Object?> get markerValues => [user];

  @override
  void build(CobaltScope scope) => scope.registerSingleton<User>(user);
}

final class OlderSessionScope extends CobaltChildScopeBuilder {
  const OlderSessionScope(this.user);

  final User user;

  @override
  Type get marker => Session;

  @override
  void build(CobaltScope scope) => scope.registerSingleton<User>(user);
}

enum Plan { free, pro }

class Account {
  const Account(this.id);

  final int id;

  @override
  bool operator ==(Object other) => other is Account && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

final class ValueScope extends CobaltChildScopeBuilder {
  const ValueScope(this.value);

  final Object value;

  @override
  Type get marker => Session;

  @override
  List<Object?> get markerValues => [value];

  @override
  void build(CobaltScope scope) {}
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

  testWidgets('a builder that does not name its values is read once', (
    tester,
  ) async {
    final app = cobaltTestRoot(name: 'app');

    final first = await show(tester, app, OlderSessionScope(ada));
    final again = await show(tester, app, OlderSessionScope(bob));

    expect(again, same(first));
    expect(find.text('ada'), findsOneWidget);
  });

  testWidgets('a hand-written builder is read once', (tester) async {
    final app = cobaltTestRoot(name: 'app');

    final first = await show(tester, app, HandWrittenScope(ada));
    final again = await show(tester, app, HandWrittenScope(bob));

    expect(again, same(first));
    expect(find.text('ada'), findsOneWidget);
  });

  group('a reopened scope', () {
    Future<List<String>> reopen(
      WidgetTester tester,
      CobaltScopeBuilder first,
      CobaltScopeBuilder second,
    ) async {
      final app = cobaltTestRoot(name: 'app');
      Future<void> pump(CobaltScopeBuilder builder) async {
        await tester.pumpWidget(
          CobaltScopeProvider(
            scope: app,
            child: CobaltScopeWidget(
              name: 'session',
              builder: builder,
              child: const SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(first);
      final printed = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message!);
      try {
        await pump(second);
      } finally {
        debugPrint = previous;
      }
      return printed;
    }

    testWidgets('by a value that compares by identity is pointed out', (
      tester,
    ) async {
      final printed = await reopen(
        tester,
        SessionScope(User('ada')),
        SessionScope(User('ada')),
      );

      expect(printed, hasLength(1));
      expect(
        printed.single,
        allOf(
          contains('CobaltScopeWidget "session" reopened'),
          contains('User compares by identity'),
          contains('Give User == and hashCode, or pass an id.'),
        ),
      );
    });

    testWidgets('by a value with its own == is not', (tester) async {
      final printed = await reopen(
        tester,
        const ValueScope(Account(1)),
        const ValueScope(Account(2)),
      );

      expect(printed, isEmpty);
    });

    testWidgets('by another enum or int value is not', (tester) async {
      expect(
        await reopen(
          tester,
          const ValueScope(Plan.free),
          const ValueScope(Plan.pro),
        ),
        isEmpty,
      );
      expect(
        await reopen(tester, const ValueScope(1), const ValueScope(2)),
        isEmpty,
      );
    });
  });
}
