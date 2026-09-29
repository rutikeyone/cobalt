import 'dart:io';

/// The snapshot stored at [path], or null when there is none.
String? readSnapshot(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

/// Stores [contents] at [path], creating its directory.
void writeSnapshot(String path, String contents) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(contents);
}

/// Whether COBALT_UPDATE_SNAPSHOTS=1 asks for snapshots to be rewritten.
bool get updateSnapshotsRequested =>
    Platform.environment['COBALT_UPDATE_SNAPSHOTS'] == '1';
