import 'dart:async';

final class BuildTiming {
  BuildTiming._(this._outer);

  factory BuildTiming.start() =>
      BuildTiming._(_current ?? Zone.current[_zoneKey] as BuildTiming?);

  static BuildTiming? _current;
  static final _zoneKey = Object();

  final BuildTiming? _outer;
  final _watch = Stopwatch()..start();
  var _nested = Duration.zero;
  Duration? _took;

  T during<T>(T Function() body) {
    final previous = _current;
    _current = this;
    try {
      return body();
    } finally {
      _current = previous;
    }
  }

  Future<T> across<T>(Future<T> Function() body) =>
      runZoned(() => during(body), zoneValues: {_zoneKey: this});

  void stop() {
    if (_took != null) return;
    final took = _took = _watch.elapsed;
    _outer?._nested += took;
  }

  Duration get took => _took ?? _watch.elapsed;

  Duration get self {
    final self = took - _nested;
    return self.isNegative ? Duration.zero : self;
  }
}
