import 'dart:async';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';

/// Where teardown is recorded, replaced by [resetLogs].
///
/// A fixture captures this at **construction**, not at teardown. Teardown is
/// not awaited by every caller, so a scope from one test can still be
/// releasing while the next runs; reading the current recorder when the
/// instance is disposed would file that report against the wrong test.
var recorder = DisposeRecorder();

final initLog = <String>[];

class Recorder implements Disposable {
  Recorder(this.label) : _recorder = recorder;

  final String label;
  final DisposeRecorder _recorder;

  @override
  void dispose() => _recorder.record(label);
}

class AsyncRecorder implements AsyncDisposable {
  AsyncRecorder(this.label) : _recorder = recorder;

  final String label;
  final DisposeRecorder _recorder;

  @override
  Future<void> dispose() async {
    await Future<void>.delayed(Duration.zero);
    _recorder.record(label);
  }
}

class Logger extends Recorder {
  Logger() : super('Logger');
}

class ApiClient extends Recorder {
  ApiClient(this.logger) : super('ApiClient');

  final Logger logger;
}

class LoggerFactory implements CobaltFactory<Logger> {
  const LoggerFactory();

  @override
  Logger create(CobaltResolver resolver) => Logger();
}

class ApiClientFactory implements CobaltFactory<ApiClient> {
  const ApiClientFactory();

  @override
  ApiClient create(CobaltResolver resolver) =>
      ApiClient(resolver.get<Logger>());
}

class PropertyTarget implements CobaltInjectable {
  late final Logger logger;
  var injected = false;

  @override
  void onInject(CobaltResolver resolver) {
    logger = resolver.get<Logger>();
    injected = true;
  }
}

class PropertyTargetFactory implements CobaltFactory<PropertyTarget> {
  const PropertyTargetFactory();

  @override
  PropertyTarget create(CobaltResolver resolver) => PropertyTarget();
}

class Greeting {
  Greeting(this.text);

  final String text;
}

class GreetingFactory implements CobaltParamFactory<Greeting, String> {
  const GreetingFactory();

  @override
  Greeting create(CobaltResolver resolver, String param) =>
      Greeting('hi $param');
}

class AnyGreetingFactory implements CobaltParamFactory<Greeting, Object> {
  const AnyGreetingFactory();

  @override
  Greeting create(CobaltResolver resolver, Object param) =>
      Greeting('hi $param');
}

class SlowService {
  SlowService(this.label);

  final String label;
}

class SlowFactory implements CobaltAsyncFactory<SlowService> {
  const SlowFactory(this.label, this.millis, {this.started});

  final String label;
  final int millis;
  final List<String>? started;

  @override
  Future<SlowService> create(CobaltResolver resolver) async {
    started?.add(label);
    await Future<void>.delayed(Duration(milliseconds: millis));
    initLog.add(label);
    return SlowService(label);
  }
}

void resetLogs() {
  recorder = DisposeRecorder();
  initLog.clear();
}

class RecorderFactory implements CobaltAsyncFactory<AsyncRecorder> {
  const RecorderFactory();

  @override
  Future<AsyncRecorder> create(CobaltResolver resolver) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return AsyncRecorder('async-singleton');
  }
}

/// Runs [body] capturing everything it prints into [lines].
void runZonedPrint(List<String> lines, void Function() body) => runZoned(
  body,
  zoneSpecification: ZoneSpecification(
    print: (_, _, _, line) => lines.add(line),
  ),
);
