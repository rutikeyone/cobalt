import 'package:cobalt/src/logging/cobalt_log_level.dart';
import 'package:cobalt/src/logging/cobalt_log_record.dart';
import 'package:cobalt/src/logging/cobalt_log_sink.dart';
import 'package:cobalt/src/logging/cobalt_recording_observer.dart';

/// Turns Cobalt's events into log records and hands them to a sink.
///
/// This is the shortest path from "I want to see what the graph is doing" to
/// output: pick a sink, pass one of these as an observer, done.
///
/// ```dart
/// final scope = await CobaltApplication.start(
///   root: const AppScope(),
///   observers: [CobaltLogObserver(const CobaltDeveloperLogSink())],
/// );
/// ```
///
/// [minimumLevel] drops anything quieter — before it is formatted, so what is
/// dropped costs next to nothing. The default keeps per-instance records out,
/// since a large graph builds a lot of them.
final class CobaltLogObserver extends CobaltRecordingObserver {
  /// Sends records to [sink], keeping those at [minimumLevel] or above.
  const CobaltLogObserver(
    this.sink, {
    this.minimumLevel = CobaltLogLevel.debug,
  });

  /// Where records go.
  final CobaltLogSink sink;

  /// The quietest level that still reaches [sink].
  final CobaltLogLevel minimumLevel;

  /// Below [minimumLevel] the record is never made, not made and dropped.
  @override
  bool accepts(CobaltLogLevel level) => level.index >= minimumLevel.index;

  @override
  void onRecord(CobaltLogRecord record) => sink.write(record);
}
