import 'dart:async';

final class BuildTiming {
  BuildTiming._(this._outer) : _watch = Stopwatch()..start();

  BuildTiming._inert() : _outer = null, _watch = null, _took = Duration.zero;

  factory BuildTiming.start({required bool observed}) {
    final outer = _current ?? Zone.current[_zoneKey] as BuildTiming?;
    if (!observed && outer == null) return _unobserved;
    return BuildTiming._(outer);
  }

  static BuildTiming? _current;
  static final _zoneKey = Object();
  static final _unobserved = BuildTiming._inert();

  final BuildTiming? _outer;
  final Stopwatch? _watch;
  var _nested = Duration.zero;
  Duration? _took;

  T during<T>(T Function() body) {
    if (_watch == null) return body();
    final previous = _current;
    _current = this;
    try {
      return body();
    } finally {
      _current = previous;
    }
  }

  Map<Object?, Object?> get zoneValues =>
      _watch == null ? const {} : {_zoneKey: this};

  void stop() {
    if (_took != null) return;
    final took = _took = _watch!.elapsed;
    _outer?._nested += took;
  }

  Duration get took => _took ?? _watch!.elapsed;

  Duration get self {
    final self = took - _nested;
    return self.isNegative ? Duration.zero : self;
  }
}
