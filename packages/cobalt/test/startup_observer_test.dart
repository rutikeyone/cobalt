import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class _Step implements CobaltBootstrapStep {
  _Step(this.name, this.millis);

  @override
  final String name;

  final int millis;

  @override
  Future<void> run() => Future<void>.delayed(Duration(milliseconds: millis));
}

class Config {}

class Database {}

class SearchIndex {
  SearchIndex(this.database);

  final Database database;
}

class Cache {}

final class _AppRoot implements CobaltScopeBuilder {
  const _AppRoot();

  @override
  void build(CobaltScope scope) => scope
    ..registerEagerSingleton<Config>(FnFactory((_) => Config()))
    ..registerLazySingleton<Cache>(FnFactory((_) => Cache()))
    ..registerAsyncSingleton<Database>(
      AsyncFnFactory((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return Database();
      }),
    )
    ..registerAsyncSingleton<SearchIndex>(
      AsyncFnFactory((resolver) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return SearchIndex(resolver.get<Database>());
      }),
      dependsOn: {const CobaltKey(Database)},
    );
}

void main() {
  test('records the bootstrap steps and what the start builds', () async {
    final startup = CobaltStartupObserver();
    final app = await CobaltApplication.start(
      root: const _AppRoot(),
      bootstrap: [_Step('BindPlatform', 1), _Step('LoadConfig', 15)],
      observers: [startup],
    );
    addTearDown(app.dispose);

    final report = startup.report;

    expect(report.bootstrap.map((it) => it.step), [
      'BindPlatform',
      'LoadConfig',
    ]);
    expect(report.builds.map((it) => it.key).toSet(), {
      const CobaltKey(Config),
      const CobaltKey(Database),
      const CobaltKey(SearchIndex),
    });
    expect(report.builds.first.key, const CobaltKey(Database));
    expect(
      report.total,
      greaterThanOrEqualTo(const Duration(milliseconds: 40)),
    );
    for (final build in report.builds) {
      expect(build.self, lessThanOrEqualTo(build.took));
    }
  });

  test('a lazy singleton built after the start is not part of it', () async {
    final startup = CobaltStartupObserver();
    final app = await CobaltApplication.start(
      root: const _AppRoot(),
      observers: [startup],
    );
    addTearDown(app.dispose);

    app.get<Cache>();

    expect(
      startup.report.builds.map((it) => it.key),
      isNot(contains(const CobaltKey(Cache))),
    );
  });

  test('a child scope is not part of the start', () async {
    final startup = CobaltStartupObserver();
    final app = await CobaltApplication.start(
      root: const _AppRoot(),
      observers: [startup],
    );
    addTearDown(app.dispose);
    final before = startup.report.builds.length;

    final session = app.push('session')
      ..registerEagerSingleton<Cache>(FnFactory((_) => Cache()));
    addTearDown(session.dispose);

    expect(startup.report.builds, hasLength(before));
  });

  test('a second start starts the report over', () async {
    final startup = CobaltStartupObserver();
    final first = await CobaltApplication.start(
      root: const _AppRoot(),
      observers: [startup],
    );
    await first.dispose();
    final second = await CobaltApplication.start(
      root: const _AppRoot(),
      observers: [startup],
    );
    addTearDown(second.dispose);

    expect(startup.report.builds, hasLength(3));
  });

  test('nothing recorded reads as an empty start', () {
    final report = CobaltStartupObserver().report;

    expect(report.total, Duration.zero);
    expect(report.bootstrap, isEmpty);
    expect(report.builds, isEmpty);
    expect('$report', 'Startup took 0µs.');
  });

  test('the summary names the slowest step and the waits', () {
    const report = CobaltStartupReport(
      total: Duration(milliseconds: 412),
      bootstrap: [
        (step: 'BindPlatform', took: Duration(milliseconds: 30)),
        (step: 'LoadRemoteConfig', took: Duration(milliseconds: 90)),
      ],
      builds: [
        (
          key: CobaltKey(SearchIndex),
          took: Duration(milliseconds: 250),
          self: Duration(milliseconds: 40),
        ),
        (
          key: CobaltKey(Database),
          took: Duration(milliseconds: 210),
          self: Duration(milliseconds: 210),
        ),
      ],
    );

    expect(
      '$report',
      'Startup took 412ms.\n'
          'Bootstrap: 120ms in 2 steps, the slowest LoadRemoteConfig (90ms).\n'
          'Slowest builds:\n'
          '  SearchIndex 250ms, 210ms waiting for its dependencies\n'
          '  Database 210ms',
    );
  });
}
