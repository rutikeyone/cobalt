import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/database.dart';

@cobaltTransient
@CobaltInit()
class Snapshot implements AsyncInitializable {
  Snapshot(this._database);

  final Database _database;

  var isTaken = false;

  @override
  Future<void> init() async {
    if (!_database.isOpen) {
      throw StateError('A Snapshot was taken before the Database was open');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
    isTaken = true;
  }
}
