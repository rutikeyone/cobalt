import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/foundation.dart';

/// The graph the lazy async entry looks at, owned by that entry alone.

/// Counts how many times the engine was built, so the screen can show that a
/// second visit builds nothing.
class EngineBuilds extends ChangeNotifier {
  var _count = 0;

  int get count => _count;

  void add() {
    _count++;
    notifyListeners();
  }
}

/// Expensive to build and wanted by one screen — a lazy async singleton.
class SearchEngine {
  SearchEngine();
}

final class SearchEngineFactory implements CobaltAsyncFactory<SearchEngine> {
  const SearchEngineFactory();

  /// Long enough to see on a device. Only a tap starts it, so no test that
  /// merely opens the entry is left with a pending timer.
  static const buildTime = Duration(milliseconds: 700);

  @override
  Future<SearchEngine> create(CobaltResolver resolver) async {
    await Future<void>.delayed(buildTime);
    resolver.get<EngineBuilds>().add();
    return SearchEngine();
  }
}

/// What the entry owns for as long as it is open.
final class LazyAsyncScope implements CobaltScopeBuilder {
  const LazyAsyncScope();

  @override
  void build(CobaltScope scope) {
    scope.registerSingleton<EngineBuilds>(EngineBuilds());
    scope.registerLazyAsyncSingleton<SearchEngine>(const SearchEngineFactory());
  }
}
