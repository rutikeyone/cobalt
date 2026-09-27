import 'package:cobalt_flutter/cobalt_flutter.dart';

/// The graph the inspector entry looks at, owned by that entry alone.
///
/// It borrows nothing from the other examples: open this one and `Graph
/// events` and you get two graphs that share no registration, no scope name
/// and no instance. Nothing here is reachable from another entry, which is the
/// property the gallery is asserting every time it builds a graph on entry and
/// disposes it on the way out.
///
/// One registration per lifetime, because telling them apart is what the
/// inspector is for — the eager singleton included, and it is the interesting
/// one: it shows in the tree and never in the built list, because the caller
/// built it and the scope only took ownership.

/// Handed to the graph already built — an eager singleton.
class Settings {
  Settings(this.channel);

  final String channel;
}

/// Built on first resolve and closed with the scope — a lazy singleton.
class Database implements Disposable {
  var isOpen = true;

  @override
  void dispose() => isOpen = false;
}

final class DatabaseFactory implements CobaltFactory<Database> {
  const DatabaseFactory();

  @override
  Database create(CobaltResolver resolver) => Database();
}

/// Needs I/O before it is usable, so it is built during `init()` — an async
/// singleton, and the reason the entry shows a loading frame at all.
class SearchIndex {
  SearchIndex(this.database);

  final Database database;
}

final class SearchIndexFactory implements CobaltAsyncFactory<SearchIndex> {
  const SearchIndexFactory();

  @override
  Future<SearchIndex> create(CobaltResolver resolver) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return SearchIndex(resolver.get<Database>());
  }
}

/// A fresh one per resolve, which the scope does not retain — a transient.
class Query {
  Query(this.database);

  final Database database;
}

final class QueryFactory implements CobaltFactory<Query> {
  const QueryFactory();

  @override
  Query create(CobaltResolver resolver) => Query(resolver.get<Database>());
}

/// Wraps every [Query] the scope hands out, so the tree shows a decorated
/// registration and its sheet names the decorator.
class TracedQuery implements Query {
  TracedQuery(this.inner);

  final Query inner;

  @override
  Database get database => inner.database;
}

final class QueryTracing implements CobaltDecorator<Query> {
  const QueryTracing();

  @override
  Query decorate(Query inner, CobaltResolver resolver) => TracedQuery(inner);
}

/// Takes a value the container cannot supply, so the inspector can describe it
/// and not build it.
class Ticket {
  Ticket(this.id);

  final String id;
}

final class TicketFactory implements CobaltParamFactory<Ticket, String> {
  const TicketFactory();

  @override
  Ticket create(CobaltResolver resolver, String param) => Ticket(param);
}

/// What the entry owns for as long as it is open.
final class InspectorScope implements CobaltScopeBuilder {
  const InspectorScope();

  @override
  void build(CobaltScope scope) {
    scope.registerSingleton<Settings>(Settings('stable'));
    scope.registerLazySingleton<Database>(const DatabaseFactory());
    scope.registerAsyncSingleton<SearchIndex>(const SearchIndexFactory());
    scope.registerFactory<Query>(const QueryFactory());
    scope.registerParamFactory<Ticket, String>(const TicketFactory());
    scope.decorate<Query>(const QueryTracing());
  }
}

/// A bootstrap step, so phase 0 shows up in the log too.
class InspectorWarmUp implements CobaltBootstrapStep, Disposable {
  InspectorWarmUp();

  @override
  String get name => 'warm-up';

  @override
  Future<void> run() async =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  @override
  void dispose() {}
}

/// Something to open and close while watching the tree.
class SessionCache implements Disposable {
  var isOpen = true;

  @override
  void dispose() => isOpen = false;
}

final class SessionCacheFactory implements CobaltAsyncFactory<SessionCache> {
  const SessionCacheFactory();

  @override
  Future<SessionCache> create(CobaltResolver resolver) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return SessionCache();
  }
}

class Draft {
  final lines = <String>[];
}

final class DraftFactory implements CobaltFactory<Draft> {
  const DraftFactory();

  @override
  Draft create(CobaltResolver resolver) => Draft();
}

/// A child scope with a life of its own, and its own lifetimes inside it.
final class InspectorSessionScope implements CobaltScopeBuilder {
  const InspectorSessionScope();

  @override
  void build(CobaltScope scope) {
    scope.registerAsyncSingleton<SessionCache>(const SessionCacheFactory());
    scope.registerLazySingleton<Draft>(const DraftFactory());
  }
}
