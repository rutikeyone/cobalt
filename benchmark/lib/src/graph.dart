/// The same small graph, registered in each container the same way.
///
/// Cobalt takes factories as objects and get_it takes closures; [Fn] and
/// [AsyncFn] wrap a closure so both sides pay for one closure call per build
/// and the comparison is of the containers, not of how a factory is spelled.
/// Generated code registers through the same calls, so what is measured here
/// holds for `@cobaltSingleton` and friends too.
library;

import 'package:cobalt/cobalt.dart';
import 'package:get_it/get_it.dart';

class Config {
  const Config(this.url);
  final String url;
}

class Api {
  Api(this.config);
  final Config config;
}

/// Built on every resolution: it takes two singletons.
class Report {
  Report(this.api, this.config);
  final Api api;
  final Config config;
}

/// One of many registrations of the same type, told apart by name. Each takes
/// the node before it, so the graph is resolved rather than merely listed.
class Node {
  Node(this.index, this.previous);
  final int index;
  final Node? previous;
}

/// Something with an async start.
class Service {
  Service(this.index);
  final int index;
}

/// A closure as a [CobaltFactory].
final class Fn<T extends Object> implements CobaltFactory<T> {
  const Fn(this._create);
  final T Function(CobaltResolver resolver) _create;

  @override
  T create(CobaltResolver resolver) => _create(resolver);
}

/// A closure as a [CobaltAsyncFactory].
final class AsyncFn<T extends Object> implements CobaltAsyncFactory<T> {
  const AsyncFn(this._create);
  final Future<T> Function(CobaltResolver resolver) _create;

  @override
  Future<T> create(CobaltResolver resolver) => _create(resolver);
}

/// How many named registrations the graph scenario makes.
const graphSize = 200;

/// How many async singletons the start scenario makes.
const asyncServices = 20;

/// [Config] and [Api] as lazy singletons, [Report] built on every resolution.
CobaltScope cobaltScope({List<CobaltObserver> observers = const []}) =>
    CobaltScope.root(observers: observers)
      ..registerLazySingleton<Config>(Fn((_) => const Config('https://api')))
      ..registerLazySingleton<Api>(Fn((r) => Api(r.get<Config>())))
      ..registerFactory<Report>(
        Fn((r) => Report(r.get<Api>(), r.get<Config>())),
      );

/// What [cobaltScope] registers, in get_it.
GetIt getItContainer() {
  final getIt = GetIt.asNewInstance();
  return getIt
    ..registerLazySingleton<Config>(() => const Config('https://api'))
    ..registerLazySingleton<Api>(() => Api(getIt<Config>()))
    ..registerFactory<Report>(() => Report(getIt<Api>(), getIt<Config>()));
}

/// [graphSize] named [Node]s in a fresh scope, then the first `get` of each.
Node cobaltGraph() {
  final scope = CobaltScope.root();
  for (var i = 0; i < graphSize; i++) {
    scope.registerLazySingleton<Node>(
      Fn((r) => Node(i, i == 0 ? null : r.get<Node>(name: 'n${i - 1}'))),
      name: 'n$i',
    );
  }
  late Node last;
  for (var i = 0; i < graphSize; i++) {
    last = scope.get<Node>(name: 'n$i');
  }
  return last;
}

/// [cobaltGraph], in get_it.
Node getItGraph() {
  final getIt = GetIt.asNewInstance();
  for (var i = 0; i < graphSize; i++) {
    getIt.registerLazySingleton<Node>(
      () => Node(i, i == 0 ? null : getIt<Node>(instanceName: 'n${i - 1}')),
      instanceName: 'n$i',
    );
  }
  late Node last;
  for (var i = 0; i < graphSize; i++) {
    last = getIt<Node>(instanceName: 'n$i');
  }
  return last;
}

/// [asyncServices] async singletons in a fresh scope, started.
Future<CobaltScope> cobaltStart() async {
  final scope = CobaltScope.root();
  for (var i = 0; i < asyncServices; i++) {
    scope.registerAsyncSingleton<Service>(
      AsyncFn((_) async => Service(i)),
      name: 's$i',
    );
  }
  await scope.init();
  return scope;
}

/// [cobaltStart], in get_it.
Future<GetIt> getItStart() async {
  final getIt = GetIt.asNewInstance();
  for (var i = 0; i < asyncServices; i++) {
    getIt.registerSingletonAsync<Service>(
      () async => Service(i),
      instanceName: 's$i',
    );
  }
  await getIt.allReady();
  return getIt;
}

/// An observer that does nothing: the price of the hooks being called at all.
final class EmptyObserver extends CobaltObserver {
  const EmptyObserver();
}

/// An observer that has every event turned into a record and drops it: the
/// price of what the log observers are built on.
final class DiscardingObserver extends CobaltRecordingObserver {
  const DiscardingObserver();

  @override
  void onRecord(CobaltLogRecord record) {}
}
