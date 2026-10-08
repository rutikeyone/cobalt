import 'package:cobalt/cobalt.dart';
import 'package:logger/web.dart' as pretty;

/// Writes Cobalt's log records to a `package:logger` logger.
///
/// ```dart
/// final scope = await CobaltApplication.start(
///   root: const AppScope(),
///   observers: [CobaltLogObserver(CobaltLoggerSink())],
/// );
/// ```
///
/// Unlike `package:logging`, this one prints by itself — the default `Logger`
/// comes with a console output and the boxed `PrettyPrinter`.
final class CobaltLoggerSink implements CobaltLogSink {
  /// Writes to [logger], or to a default one.
  CobaltLoggerSink({pretty.Logger? logger})
    : _logger = logger ?? pretty.Logger();

  final pretty.Logger _logger;

  /// The logger records are written to.
  pretty.Logger get logger => _logger;

  @override
  void write(CobaltLogRecord record) => _logger.log(
    levelOf(record.level),
    record.message,
    error: record.error,
    stackTrace: record.stackTrace,
  );

  /// Maps an Cobalt level onto `package:logger`'s enum.
  ///
  /// Every value maps to a real level: `Logger.log` throws `ArgumentError` on
  /// `all`, `off` and `nothing`, so none of those may appear here.
  static pretty.Level levelOf(CobaltLogLevel level) => switch (level) {
    CobaltLogLevel.trace => pretty.Level.trace,
    CobaltLogLevel.debug => pretty.Level.debug,
    CobaltLogLevel.info => pretty.Level.info,
    CobaltLogLevel.warning => pretty.Level.warning,
    CobaltLogLevel.error => pretty.Level.error,
  };
}
