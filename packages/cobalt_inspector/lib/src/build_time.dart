/// A build time as the inspector shows it: microseconds below a millisecond
/// — most builds are — milliseconds below a second, seconds above.
String formatBuildTime(Duration took) {
  final micros = took.inMicroseconds;
  if (micros < 1000) return '$micros µs';
  if (micros < 1000000) return '${(micros / 1000).toStringAsFixed(1)} ms';
  return '${(micros / 1000000).toStringAsFixed(2)} s';
}
