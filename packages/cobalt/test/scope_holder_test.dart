import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class Account {
  Account(this.id);

  final String id;
}

final class Session implements CobaltScopeBuilder {
  const Session(this.id, {this.ready, this.fails = false});

  final String id;
  final Future<void>? ready;
  final bool fails;

  @override
  void build(CobaltScope scope) {
    if (fails) throw StateError('no session for $id');
    scope.registerAsyncSingleton<Account>(
      AsyncFnFactory((_) async {
        await ready;
        return Account(id);
      }),
    );
  }
}

void main() {
  late CobaltScope app;
  late CobaltScopeHolder holder;
  late List<String?> changes;
  late StreamSubscription<CobaltScope?> subscription;

  setUp(() {
    app = cobaltTestRoot(name: 'app');
    holder = CobaltScopeHolder(app);
    changes = [];
    subscription = holder.changes.listen((scope) => changes.add(scope?.name));
  });

  tearDown(() async {
    await subscription.cancel();
    await app.dispose();
  });

  test('holds what it opened', () async {
    final scope = await holder.open('session:1', const Session('1'));

    expect(holder.current, same(scope));
    expect(scope.get<Account>().id, '1');
    await pumpEventQueue();
    expect(changes, ['session:1']);
  });

  test('closes the scope it holds before opening the next', () async {
    final first = await holder.open('session:1', const Session('1'));
    final second = await holder.open('session:2', const Session('2'));

    expect(first.state, CobaltScopeState.disposed);
    expect(holder.current, same(second));
    await pumpEventQueue();
    expect(changes, ['session:1', null, 'session:2']);
  });

  test(
    'a close called while an open is initializing closes that scope',
    () async {
      final ready = Completer<void>();
      final opening = holder.open(
        'session:1',
        Session('1', ready: ready.future),
      );
      final closing = holder.close();
      ready.complete();

      final opened = await opening;
      await closing;

      expect(opened.state, CobaltScopeState.disposed);
      expect(holder.current, isNull);
    },
  );

  test('a builder that throws leaves nothing held', () async {
    await holder.open('session:1', const Session('1'));

    await expectLater(
      holder.open('session:2', const Session('2', fails: true)),
      throwsStateError,
    );

    expect(holder.current, isNull);
    expect(app.children, isEmpty);
    await pumpEventQueue();
    expect(changes, ['session:1', null]);
  });

  test('a close with nothing held changes nothing', () async {
    await holder.close();

    await pumpEventQueue();
    expect(changes, isEmpty);
  });

  test('holds nothing once the parent is disposed', () async {
    await holder.open('session:1', const Session('1'));

    await app.dispose();

    expect(holder.current, isNull);
  });

  test('dispose closes the held scope and refuses another open', () async {
    final scope = await holder.open('session:1', const Session('1'));

    await holder.dispose();

    expect(scope.state, CobaltScopeState.disposed);
    await expectLater(
      holder.open('session:2', const Session('2')),
      throwsA(isA<CobaltScopeStateError>()),
    );
    await pumpEventQueue();
    expect(changes, ['session:1', null]);
  });
}
