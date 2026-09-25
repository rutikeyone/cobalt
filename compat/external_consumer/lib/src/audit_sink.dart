import 'package:cobalt/cobalt.dart';

@CobaltInit()
class AuditSink implements AsyncInitializable {
  AuditSink();

  final lines = <String>[];

  @override
  Future<void> init() => Future<void>.delayed(const Duration(milliseconds: 5));
}
