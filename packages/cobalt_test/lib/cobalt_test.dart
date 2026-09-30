/// Test helpers for Cobalt.
///
/// Pure Dart on `test_api` and `matcher` rather than the full `test` runner, so
/// the same helpers work under `dart test` and `flutter test` without a second
/// package and without putting `flutter_test` in anything that does not need
/// it.
library;

export 'package:cobalt_test/src/cobalt_graph_report.dart';
export 'package:cobalt_test/src/capturing_observer.dart';
export 'package:cobalt_test/src/check_graph.dart';
export 'package:cobalt_test/src/dispose_recorder.dart';
export 'package:cobalt_test/src/graph_mermaid.dart';
export 'package:cobalt_test/src/graph_snapshot.dart';
export 'package:cobalt_test/src/test_factories.dart';
export 'package:cobalt_test/src/test_scopes.dart';
