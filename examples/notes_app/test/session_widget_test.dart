import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/cobalt.g.dart';
import 'package:notes_app/features/session/data/session_activity_log.dart';
import 'package:notes_app/features/session/domain/session_user.dart';

import 'support.dart';

class _SignedIn extends StatelessWidget {
  const _SignedIn();

  @override
  Widget build(BuildContext context) =>
      Text(context.cobalt<SessionUser>().displayName);
}

void main() {
  const ada = SessionUser(id: 'u-1', displayName: 'Ada');
  const bob = SessionUser(id: 'u-2', displayName: 'Bob');

  testWidgets(
    'another user under the same widget gets a session of their own',
    (tester) async {
      final app = (await tester.runAsync(startNotesGraph))!;

      Future<SessionActivityLog> signIn(SessionUser user) async {
        await tester.pumpWidget(
          CobaltScopeProvider(
            scope: app,
            child: MaterialApp(
              home: CobaltScopeWidget(
                builder: SessionScope(user),
                child: const _SignedIn(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return app.children.single.get<SessionActivityLog>();
      }

      final first = await signIn(ada);
      expect(find.text('Ada'), findsOneWidget);

      final second = await signIn(bob);
      expect(find.text('Bob'), findsOneWidget);
      expect(first.isClosed, isTrue);
      expect(second.isClosed, isFalse);

      expect(await signIn(bob), same(second));
    },
  );
}
