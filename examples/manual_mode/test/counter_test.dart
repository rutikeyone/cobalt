import 'package:cobalt/cobalt.dart';
import 'package:manual_mode/counter.dart';
import 'package:test/test.dart';

void main() {
  late CobaltScope app;

  setUp(() async => app = await startApp());
  tearDown(() async => app.dispose());

  test('async storage is ready as soon as start returns', () {
    expect(app.state, CobaltScopeState.active);
    expect(app.get<EventLog>().entries, contains('storage warmed up'));
  });

  test(
    'a session scope resolves parents and its own parameterized factory',
    () {
      final session = openSession(app, 'alice');
      final counter = session.getWithParam<Counter, String>('alice');

      counter
        ..increment()
        ..increment();

      expect(counter.value, 2);
      expect(app.get<EventLog>().entries, contains('alice -> 2'));
    },
  );

  test('the session decorates every counter it builds', () {
    final session = openSession(app, 'alice');
    session.getWithParam<Counter, String>('alice').increment();

    expect(
      app.get<EventLog>().entries,
      containsAllInOrder(['alice -> 1', 'audited alice']),
    );
    expect(session.debugDecoratorsOf(const CobaltKey(Counter)), [
      'AuditedCounterDecorator',
    ]);
  });

  test('two sessions share app singletons but keep separate counters', () {
    final alice = openSession(app, 'alice');
    final bob = openSession(app, 'bob');

    alice.getWithParam<Counter, String>('alice').increment();
    bob.getWithParam<Counter, String>('bob')
      ..increment()
      ..increment();

    expect(alice.getWithParam<Counter, String>('alice').value, 1);
    expect(bob.getWithParam<Counter, String>('bob').value, 2);
    expect(app.children, hasLength(2));
  });

  test('closing a session leaves the app scope intact', () async {
    final session = openSession(app, 'alice');
    await session.dispose();

    expect(app.children, isEmpty);
    expect(app.get<CounterStorage>().isClosed, isFalse);
    expect(app.state, CobaltScopeState.active);
  });

  test('disposing the app closes sessions first, then async storage', () async {
    openSession(app, 'alice');
    final log = app.get<EventLog>();

    await app.dispose();

    expect(log.entries, contains('storage closed'));
    expect(log.isClosed, isTrue);
    expect(log.entries.last, 'storage closed');
  });
}
