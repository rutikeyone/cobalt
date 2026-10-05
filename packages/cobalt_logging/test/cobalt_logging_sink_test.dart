import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:cobalt_logging/cobalt_logging.dart';
import 'package:logging/logging.dart' as logging;
import 'package:test/test.dart';

void main() {
  late List<logging.LogRecord> records;
  late CobaltLoggingSink sink;

  setUp(() {
    records = [];
    logging.hierarchicalLoggingEnabled = true;
    final logger = logging.Logger.detached('cobalt-test')
      ..level = logging.Level.ALL;
    logger.onRecord.listen(records.add);
    sink = CobaltLoggingSink(logger: logger);
  });

  group('CobaltLoggingSink', () {
    test('without a logger it builds one named "cobalt", reachable through '
        '.logger', () {
      final sink = CobaltLoggingSink();

      expect(sink.logger, isA<logging.Logger>());
      expect(sink.logger.fullName, 'cobalt');
    });

    test('a name picks which logger it builds', () {
      final sink = CobaltLoggingSink(name: 'cobalt.network');

      expect(sink.logger.fullName, 'cobalt.network');
    });

    test('every Cobalt level maps onto a logging one', () {
      expect(
        CobaltLoggingSink.levelOf(CobaltLogLevel.trace),
        logging.Level.FINEST,
      );
      expect(
        CobaltLoggingSink.levelOf(CobaltLogLevel.debug),
        logging.Level.FINE,
      );
      expect(
        CobaltLoggingSink.levelOf(CobaltLogLevel.info),
        logging.Level.INFO,
      );
      expect(
        CobaltLoggingSink.levelOf(CobaltLogLevel.warning),
        logging.Level.WARNING,
      );
      expect(
        CobaltLoggingSink.levelOf(CobaltLogLevel.error),
        logging.Level.SEVERE,
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
          stackTrace: StackTrace.empty,
        ),
      );

      expect(records.single.message, 'it broke');
      expect(records.single.level, logging.Level.SEVERE);
      expect(records.single.error, same(boom));
    });

    test('the graph drives it end to end', () async {
      final root = cobaltTestRoot(
        name: 'app',
        observers: [CobaltLogObserver(sink)],
      );
      root.push('session');
      await root.dispose();

      expect(
        records.map((r) => r.message),
        containsAllInOrder(<String>[
          'scope "app/session" pushed',
          'scope "app/session" disposing',
        ]),
      );
    });

    test('minimumLevel keeps per-instance noise out by default', () {
      final root = cobaltTestRoot(
        name: 'app',
        observers: [CobaltLogObserver(sink)],
      )..registerLazySingleton<Object>(FnFactory((_) => Object()));

      root.get<Object>();

      expect(records.where((r) => r.message.startsWith('built')), isEmpty);
    });

    test('lowering minimumLevel lets them through', () {
      final root = cobaltTestRoot(
        name: 'app',
        observers: [
          CobaltLogObserver(sink, minimumLevel: CobaltLogLevel.trace),
        ],
      )..registerLazySingleton<Object>(FnFactory((_) => Object()));

      root.get<Object>();

      expect(records.map((r) => r.message), contains(startsWith('built')));
    });
  });
}
