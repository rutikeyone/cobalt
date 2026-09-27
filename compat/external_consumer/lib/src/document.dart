import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/database.dart';

@CobaltInit()
class Document implements AsyncInitializable {
  Document(this._database, {@cobaltParam required this.id});

  final Database _database;
  final int id;

  var isLoaded = false;

  @override
  Future<void> init() async {
    if (!_database.isOpen) {
      throw StateError('Document $id was loaded before the Database was open');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
    isLoaded = true;
  }
}
