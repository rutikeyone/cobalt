import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/audit_sink.dart';

@CobaltInit(dependsOn: [AuditSink])
class AuditTrail implements AsyncInitializable {
  AuditTrail(this._sink);

  final AuditSink _sink;

  List<String> get lines => _sink.lines;

  void record(String line) => _sink.lines.add(line);

  @override
  Future<void> init() => Future<void>.delayed(const Duration(milliseconds: 5));
}
