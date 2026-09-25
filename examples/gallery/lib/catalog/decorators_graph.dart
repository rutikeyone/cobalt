import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/foundation.dart';

/// The graph the decorators entry looks at, owned by that entry alone.

/// What the screen shows: how often the real service was reached, and every
/// answer handed out.
class ForecastLog extends ChangeNotifier {
  var _stationCalls = 0;
  final _answers = <String>[];

  int get stationCalls => _stationCalls;

  List<String> get answers => List.unmodifiable(_answers);

  void stationCalled() {
    _stationCalls++;
    notifyListeners();
  }

  void answered(String answer) {
    _answers.add(answer);
    notifyListeners();
  }
}

/// The type everyone asks for.
abstract interface class Weather {
  String forecast(String city);
}

/// The real service: slow and metered, in the story.
class Station implements Weather {
  Station(this._log);

  final ForecastLog _log;

  @override
  String forecast(String city) {
    _log.stationCalled();
    return '$city ${city.length * 3}°';
  }
}

/// Answers a city it has seen from memory.
class Cached implements Weather {
  Cached(this._inner);

  final Weather _inner;
  final _seen = <String, String>{};

  @override
  String forecast(String city) =>
      _seen.putIfAbsent(city, () => _inner.forecast(city));
}

/// Records every answer, cached or not, because it sits outside the cache.
class Logged implements Weather {
  Logged(this._inner, this._log);

  final Weather _inner;
  final ForecastLog _log;

  @override
  String forecast(String city) {
    final answer = _inner.forecast(city);
    _log.answered(answer);
    return answer;
  }
}

final class StationFactory implements CobaltFactory<Weather> {
  const StationFactory();

  @override
  Weather create(CobaltResolver resolver) =>
      Station(resolver.get<ForecastLog>());
}

final class CachingDecorator implements CobaltDecorator<Weather> {
  const CachingDecorator();

  @override
  Weather decorate(Weather inner, CobaltResolver resolver) => Cached(inner);
}

final class LoggingDecorator implements CobaltDecorator<Weather> {
  const LoggingDecorator();

  @override
  Weather decorate(Weather inner, CobaltResolver resolver) =>
      Logged(inner, resolver.get<ForecastLog>());
}

/// What the entry owns for as long as it is open. The first decorator added
/// is the innermost, so logging sees cached answers too.
final class DecoratorsScope implements CobaltScopeBuilder {
  const DecoratorsScope();

  @override
  void build(CobaltScope scope) => scope
    ..registerSingleton<ForecastLog>(ForecastLog())
    ..registerLazySingleton<Weather>(const StationFactory())
    ..decorate<Weather>(const CachingDecorator())
    ..decorate<Weather>(const LoggingDecorator());
}
