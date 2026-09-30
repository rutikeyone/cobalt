import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when `init()` runs past the timeout it was given.
///
/// Names what had not finished, which is the question a hung start leaves: a
/// splash screen that never goes away says nothing about which of twenty
/// initializers is waiting on a socket.
final class CobaltInitTimeoutError extends CobaltError {
  /// [scopeName] did not finish within [timeout]; [pending] were not built.
  CobaltInitTimeoutError(this.scopeName, this.timeout, this.pending)
    : super(
        'Scope "$scopeName" did not finish init() within '
        '${timeout.inMilliseconds}ms. Not built yet: '
        '${pending.join(', ')}. Builds still in flight run to the end and '
        'are released as they arrive; nothing after them starts.',
      );

  /// The scope whose init() timed out.
  final String scopeName;

  /// The budget it was given.
  final Duration timeout;

  /// The async singletons that were not ready when it ran out — in flight,
  /// or waiting on one that was.
  final List<CobaltKey> pending;
}
