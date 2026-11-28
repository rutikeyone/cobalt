import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/audit_sink.dart';

@cobaltInit
class AuditSummary implements AsyncInitializable {
  AuditSummary(this.sink);

  final AuditSink sink;

  var isReady = false;

  @override
  Future<void> init() async => isReady = true;
}
