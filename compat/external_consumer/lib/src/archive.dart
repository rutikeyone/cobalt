import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/database.dart';

@CobaltInit(lazy: true)
class Archive implements AsyncInitializable {
  Archive(this.database);

  final Database database;

  var isOpen = false;

  @override
  Future<void> init() async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    isOpen = true;
  }
}

@cobaltLazyInit
class ArchiveIndex implements AsyncInitializable {
  ArchiveIndex(this.archive);

  final Archive archive;

  var isBuilt = false;

  @override
  Future<void> init() async {
    if (!archive.isOpen) {
      throw StateError('ArchiveIndex was built before its Archive was open');
    }
    isBuilt = true;
  }
}
