import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/audit_trail.dart';
import 'package:cobalt_external_consumer/src/database.dart';

@CobaltDecorates(Database)
class AuditedDatabase implements Database {
  AuditedDatabase(this.inner, this._trail) {
    _trail.record('database handed out');
  }

  final Database inner;
  final AuditTrail _trail;

  @override
  bool get isOpen => inner.isOpen;

  @override
  set isOpen(bool value) => inner.isOpen = value;

  @override
  Future<void> init() => inner.init();
}
