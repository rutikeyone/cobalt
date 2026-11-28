import 'package:cobalt/src/errors/troubleshooting_link.dart';

/// Base class for everything Cobalt throws at runtime.
///
/// Extends `StateError` because most cases mean the container was asked for
/// something it cannot deliver in its current state — a programming error, not
/// a condition to recover from at runtime.
///
/// Four failures come from the environment instead, and also implement
/// [Exception], so `on Exception` catches them: `CobaltBootstrapError`,
/// `CobaltInitTimeoutError`, `CobaltWarmUpError` and `CobaltDisposeError`.
base class CobaltError extends StateError {
  /// Creates an error carrying [message].
  CobaltError(super.message);

  @override
  String toString() => '${super.toString()}\n${troubleshootingLink(this)}';
}
