import 'package:cobalt/cobalt.dart';
import 'package:codegen_basics/services.dart';

/// Wraps the one `Repository` the container hands out, without touching it.
///
/// Every `get<Repository>()` — the bloc's injected field included — receives
/// this instead. Logging, a cache or a retry go the same way: a class
/// implementing the type, taking the instance it wraps.
@CobaltDecorates(Repository)
class TrackedRepository implements Repository {
  TrackedRepository(this._inner);

  final Repository _inner;

  var writes = 0;

  @override
  Config get config => _inner.config;

  @override
  int read(String key) => _inner.read(key);

  @override
  void write(String key, int value) {
    writes++;
    _inner.write(key, value);
  }
}
