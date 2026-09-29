import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testing_patterns/testing_patterns.dart';

/// The production graph's shape, kept next to the tests.
///
/// A new registration, a lifetime changed, a decorator added — each shows up
/// here as a failing test with a diff, so the change is looked at in review
/// rather than noticed on a device. Accepting it is rewriting the file:
///
/// ```bash
/// COBALT_UPDATE_SNAPSHOTS=1 flutter test test/graph_snapshot_test.dart
/// ```
void main() {
  test('the production graph keeps its shape', () async {
    final app = await cobaltTestScope(root: const AppScope(), rootName: 'app');

    expectGraphSnapshot(app, 'test/app_graph.snapshot');
  });
}
