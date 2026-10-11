import 'package:cobalt/cobalt.dart';
import 'package:test/test.dart';

import 'support.dart';

final _ran = <String>[];

final class _Step implements CobaltBootstrapStep {
  @override
  String get name => 'step';

  @override
  Future<void> run() async => _ran.add(name);
}

final class _AppRoot extends CobaltRootBuilder {
  const _AppRoot();

  @override
  String get name => 'app';

  @override
  List<CobaltBootstrapStep> bootstrap() => [_Step()];

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<Logger>(const LoggerFactory());
}

final class _Unnamed extends CobaltRootBuilder {
  const _Unnamed();

  @override
  void build(CobaltScope scope) {}
}

void main() {
  setUp(() {
    resetLogs();
    _ran.clear();
  });

  test('the root takes the name its builder gives', () async {
    final scope = await CobaltApplication.start(root: const _AppRoot());
    addTearDown(scope.dispose);

    expect(scope.name, 'app');
    expect(scope.get<Logger>(), isA<Logger>());
  });

  test('a rootName passed explicitly wins', () async {
    final scope = await CobaltApplication.start(
      root: const _AppRoot(),
      rootName: 'notes',
    );
    addTearDown(scope.dispose);

    expect(scope.name, 'notes');
  });

  test('a builder that names nothing starts as root', () async {
    final scope = await CobaltApplication.start(root: const _Unnamed());
    addTearDown(scope.dispose);

    expect(scope.name, 'root');
  });

  test('its bootstrap runs only when passed', () async {
    final without = await CobaltApplication.start(root: const _AppRoot());
    await without.dispose();
    expect(_ran, isEmpty);

    final root = const _AppRoot();
    final scope = await CobaltApplication.start(
      root: root,
      bootstrap: root.bootstrap(),
    );
    addTearDown(scope.dispose);
    expect(_ran, ['step']);
  });
}
