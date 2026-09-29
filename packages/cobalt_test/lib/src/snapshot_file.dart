// The platforms without a file system: the snapshot text still works, only
// reading and writing it does not.

/// The snapshot stored at [path], or null when there is none.
String? readSnapshot(String path) => throw UnsupportedError(
  'expectGraphSnapshot reads a file, and this platform has no file system. '
  'Compare describeGraph(scope) with a string instead.',
);

/// Stores [contents] at [path], creating its directory.
void writeSnapshot(String path, String contents) => throw UnsupportedError(
  'expectGraphSnapshot writes a file, and this platform has no file system.',
);

/// Whether COBALT_UPDATE_SNAPSHOTS=1 asks for snapshots to be rewritten.
bool get updateSnapshotsRequested => false;
