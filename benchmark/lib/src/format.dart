/// [nanos] in the unit that keeps it between 1 and 1000: `42 ns`, `3.1 µs`.
String formatNanos(double nanos) {
  if (nanos < 1000) return '${nanos.toStringAsFixed(nanos < 10 ? 1 : 0)} ns';
  final micros = nanos / 1000;
  if (micros < 1000) {
    return '${micros.toStringAsFixed(micros < 10 ? 2 : 1)} µs';
  }
  return '${(micros / 1000).toStringAsFixed(2)} ms';
}
