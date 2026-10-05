import 'package:cobalt/cobalt.dart';
import 'package:cobalt_logger/cobalt_logger.dart';
import 'package:logger/logger.dart' as pretty;
import 'package:test/test.dart';

void main() {
  late List<pretty.LogEvent> events;
  late void Function(pretty.LogEvent) listener;
  late CobaltLoggerSink sink;

  setUp(() {
    events = [];
    listener = events.add;
    pretty.Logger.addLogListener(listener);
    sink = CobaltLoggerSink(
      logger: pretty.Logger(level: pretty.Level.trace, output: _SilentOutput()),
    );
  });

  tearDown(() => pretty.Logger.removeLogListener(listener));

  group('CobaltLoggerSink', () {
    test('without a logger it builds one of its own, reachable through '
        '.logger', () {
      final sink = CobaltLoggerSink();
      addTearDown(sink.logger.close);

      expect(sink.logger, isA<pretty.Logger>());
    });

    test('every Cobalt level maps onto a real logger level', () {
      expect(
        CobaltLoggerSink.levelOf(CobaltLogLevel.trace),
        pretty.Level.trace,
      );
      expect(
        CobaltLoggerSink.levelOf(CobaltLogLevel.debug),
        pretty.Level.debug,
      );
      expect(CobaltLoggerSink.levelOf(CobaltLogLevel.info), pretty.Level.info);
      expect(
        CobaltLoggerSink.levelOf(CobaltLogLevel.warning),
        pretty.Level.warning,
      );
      expect(
        CobaltLoggerSink.levelOf(CobaltLogLevel.error),
        pretty.Level.error,
      );
      expect(
        [
          pretty.Level.all,
          pretty.Level.off,
        ].contains(CobaltLoggerSink.levelOf(CobaltLogLevel.trace)),
        isFalse,
        reason: 'Logger.log throws ArgumentError on all/off',
      );
    });

    test('a record reaches the logger with its error attached', () {
      final boom = StateError('boom');
      sink.write(
        CobaltLogRecord(
          kind: CobaltEventKind.scopeInitFailed,
          level: CobaltLogLevel.error,
          message: 'it broke',
          error: boom,
        ),
      );

      expect(events.single.message, 'it broke');
      expect(events.single.level, pretty.Level.error);
      expect(events.single.error, same(boom));
    });

    test('the graph drives it end to end', () async {
      final root = CobaltScope.root(
        name: 'app',
        observers: [CobaltLogObserver(sink)],
      );
      root.push('session');
      await root.dispose();

      expect(
        events.map((e) => e.message),
        containsAllInOrder(<Object>[
          'scope "app/session" pushed',
          'scope "app/session" disposing',
        ]),
      );
    });
  });
}

class _SilentOutput extends pretty.LogOutput {
  @override
  void output(pretty.OutputEvent event) {}
}
