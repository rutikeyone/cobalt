import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

class _Promises implements CobaltScopeBuilder {
  const _Promises({this.keep = false});

  final bool keep;

  @override
  void build(CobaltScope scope) {
    scope
      ..promise<Logger>()
      ..promise<Logger>(name: 'audit');
    if (keep) {
      scope
        ..registerLazySingleton<Logger>(const LoggerFactory())
        ..registerLazySingleton<Logger>(const LoggerFactory(), name: 'audit');
    }
  }
}

void main() {
  setUp(resetLogs);

  test('a promise kept says nothing', () async {
    final events = CapturingObserver();

    await cobaltTestScope(
      root: const _Promises(keep: true),
      observers: [events],
    );

    expect(events.saw(CobaltEventKind.promiseBroken), isFalse);
  });

  test('a promise broken is a warning, not an error', () async {
    final events = CapturingObserver();

    final scope = await cobaltTestScope(
      root: const _Promises(),
      rootName: 'app',
      observers: [events],
    );

    expect(scope.state, CobaltScopeState.active);
    final broken = events.ofKind(CobaltEventKind.promiseBroken);
    expect(broken.map((record) => record.key), [
      const CobaltKey(Logger),
      const CobaltKey(Logger, name: 'audit'),
    ]);
    expect(broken.first.level, CobaltLogLevel.warning);
    expect(
      broken.first.message,
      'Logger was promised to "app" but nothing there registered it',
    );
  });

  test('a promise is checked in the scope it was made to', () async {
    final events = CapturingObserver();
    final app = cobaltTestRoot(name: 'app', observers: [events])
      ..registerLazySingleton<Logger>(const LoggerFactory());

    final session = await app.open('session', const _Promises());
    addTearDown(session.dispose);

    expect(
      events.ofKind(CobaltEventKind.promiseBroken).map((r) => '${r.scope}'),
      ['app/session', 'app/session'],
      reason: 'an ancestor registering the key does not keep the promise',
    );
  });
}
