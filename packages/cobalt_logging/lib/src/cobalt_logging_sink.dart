import 'package:cobalt/cobalt.dart';
import 'package:logging/logging.dart' as logging;

/// Writes Cobalt's log records to a `package:logging` logger.
///
/// ```dart
/// final scope = await CobaltApplication.start(
///   root: const AppScope(),
///   observers: [CobaltLogObserver(CobaltLoggingSink())],
/// );
/// ```
///
/// Nothing is printed until something listens — `package:logging` is a routing
/// layer, not an output. The usual setup is
/// `Logger.root.onRecord.listen(print)` plus a `Logger.root.level`.
final class CobaltLoggingSink implements CobaltLogSink {
  /// Writes to a logger named [name], or to [logger] when one is given.
  CobaltLoggingSink({String name = 'cobalt', logging.Logger? logger})
    : _logger = logger ?? logging.Logger(name);

  final logging.Logger _logger;

  /// The logger records are written to.
  logging.Logger get logger => _logger;

  @override
  void write(CobaltLogRecord record) => _logger.log(
    levelOf(record.level),
    record.message,
    record.error,
    record.stackTrace,
  );

  /// Maps a Cobalt level onto `package:logging`'s scale.
  ///
  /// `trace` lands on `FINEST` rather than `FINE`, because Cobalt's trace is
  /// per-instance and a graph of any size produces a lot of it.
  static logging.Level levelOf(CobaltLogLevel level) => switch (level) {
    CobaltLogLevel.trace => logging.Level.FINEST,
    CobaltLogLevel.debug => logging.Level.FINE,
    CobaltLogLevel.info => logging.Level.INFO,
    CobaltLogLevel.warning => logging.Level.WARNING,
    CobaltLogLevel.error => logging.Level.SEVERE,
  };
}
