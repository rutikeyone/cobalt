import 'package:cobalt/cobalt.dart';

class Clock {
  DateTime now() => DateTime.now();
}

class EventLog implements Disposable {
  final entries = <String>[];
  var isClosed = false;

  void add(String entry) => entries.add(entry);

  @override
  void dispose() => isClosed = true;
}

class CounterStorage implements AsyncDisposable {
  CounterStorage(this._log);

  final EventLog _log;
  final _values = <String, int>{};
  var isClosed = false;

  Future<void> warmUp() async {
    await Future<void>.delayed(Duration.zero);
    _log.add('storage warmed up');
  }

  int read(String key) => _values[key] ?? 0;

  void write(String key, int value) => _values[key] = value;

  @override
  Future<void> dispose() async {
    isClosed = true;
    _log.add('storage closed');
  }
}

class Counter {
  Counter(this._storage, this._log, this.sessionId);

  final CounterStorage _storage;
  final EventLog _log;
  final String sessionId;

  int get value => _storage.read(sessionId);

  void increment() {
    _storage.write(sessionId, value + 1);
    _log.add('$sessionId -> $value');
  }
}

class AuditedCounter implements Counter {
  AuditedCounter(this._inner, this._log);

  final Counter _inner;

  @override
  final EventLog _log;

  @override
  CounterStorage get _storage => _inner._storage;

  @override
  String get sessionId => _inner.sessionId;

  @override
  int get value => _inner.value;

  @override
  void increment() {
    _inner.increment();
    _log.add('audited $sessionId');
  }
}

class AuditedCounterDecorator implements CobaltDecorator<Counter> {
  const AuditedCounterDecorator();

  @override
  Counter decorate(Counter inner, CobaltResolver resolver) =>
      AuditedCounter(inner, resolver.get<EventLog>());
}

class ClockFactory implements CobaltFactory<Clock> {
  const ClockFactory();

  @override
  Clock create(CobaltResolver resolver) => Clock();
}

class EventLogFactory implements CobaltFactory<EventLog> {
  const EventLogFactory();

  @override
  EventLog create(CobaltResolver resolver) => EventLog();
}

class CounterStorageFactory implements CobaltAsyncFactory<CounterStorage> {
  const CounterStorageFactory();

  @override
  Future<CounterStorage> create(CobaltResolver resolver) async {
    final storage = CounterStorage(resolver.get<EventLog>());
    await storage.warmUp();
    return storage;
  }
}

class CounterFactory implements CobaltParamFactory<Counter, String> {
  const CounterFactory();

  @override
  Counter create(CobaltResolver resolver, String param) =>
      Counter(resolver.get<CounterStorage>(), resolver.get<EventLog>(), param);
}

class BindPlatform implements CobaltBootstrapStep {
  const BindPlatform();

  @override
  String get name => 'platform-binding';

  @override
  void run() {}
}

class AppScope implements CobaltScopeBuilder {
  const AppScope();

  @override
  void build(CobaltScope scope) {
    scope
      ..registerLazySingleton<Clock>(const ClockFactory())
      ..registerLazySingleton<EventLog>(const EventLogFactory())
      ..registerAsyncSingleton<CounterStorage>(const CounterStorageFactory());
  }
}

CobaltScope openSession(CobaltScope root, String id) => root.push('session:$id')
  ..registerParamFactory<Counter, String>(const CounterFactory())
  ..decorate<Counter>(const AuditedCounterDecorator());

Future<CobaltScope> startApp({List<CobaltObserver> observers = const []}) =>
    CobaltApplication.start(
      root: const AppScope(),
      bootstrap: const [BindPlatform()],
      rootName: 'app',
      observers: observers,
    );
