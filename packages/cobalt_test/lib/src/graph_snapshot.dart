import 'package:cobalt/cobalt.dart';
// A file system only where there is one: importing dart:io unconditionally
// would cost this package every platform without it, WebAssembly included.
import 'package:cobalt_test/src/snapshot_file.dart'
    if (dart.library.io) 'package:cobalt_test/src/snapshot_file_io.dart';
import 'package:matcher/expect.dart' show fail;

/// What [scope] and the scopes below it register, as text.
///
/// One block per scope, nested as the tree is; inside each, the keys that
/// scope registers itself, sorted, with their kind, whether an override
/// stands in for them and what decorates them, innermost first:
///
/// ```text
/// scope "app"
///   ApiClient — lazySingleton, decorated: Retrying → Logging
///   Clock — singleton, overridden
///   scope "session"
///     Cart — lazySingleton
/// ```
///
/// Nothing is built, unlike `checkGraph`: it reads what the scope declares,
/// so it is safe anywhere in a test and leaves teardown order alone. The
/// lifecycle state is left out on purpose — a snapshot taken before and after
/// `init()` describes the same graph.
///
/// The exact wording is not a contract beyond this: a change to it is a
/// change a snapshot will show, and is called out in the changelog.
String describeGraph(CobaltScope scope) {
  final lines = <String>[];
  void describe(CobaltScope scope, String indent) {
    lines.add('${indent}scope "${scope.name}"');
    final keys = scope.keys.toList()..sort((a, b) => '$a'.compareTo('$b'));
    for (final key in keys) {
      final facts = [
        scope.debugKindOf(key)?.name ?? 'unknown',
        if (scope.overriddenKeys.contains(key)) 'overridden',
        if (scope.debugDecoratorsOf(key) case final decorators
            when decorators.isNotEmpty)
          'decorated: ${decorators.join(' → ')}',
      ];
      lines.add('$indent  $key — ${facts.join(', ')}');
    }
    for (final child in scope.children) {
      describe(child, '$indent  ');
    }
  }

  describe(scope, '');
  return '${lines.join('\n')}\n';
}

/// Fails unless [describeGraph] of [scope] matches the snapshot stored at
/// [path], relative to the package the tests run in.
///
/// A graph that changes shape is usually a change someone meant to make —
/// a new registration, a lifetime changed, a decorator added. The snapshot
/// makes that visible in review: the test fails, the diff says what moved,
/// and accepting it is rewriting the file and committing it.
///
/// Rewrite it with [update], or by running the tests with
/// `COBALT_UPDATE_SNAPSHOTS=1`. A snapshot that does not exist yet fails too,
/// rather than being written and passing: in CI that would pass without
/// having checked anything.
///
/// Reading and writing need a file system; on the web and in WebAssembly this
/// throws `UnsupportedError` — compare [describeGraph] with a string there.
void expectGraphSnapshot(CobaltScope scope, String path, {bool? update}) {
  final actual = describeGraph(scope);
  if (update ?? updateSnapshotsRequested) {
    writeSnapshot(path, actual);
    return;
  }

  final expected = readSnapshot(path);
  if (expected == null) {
    fail(
      'No graph snapshot at $path. This is the graph now:\n\n$actual\n'
      'If it is right, write the file by running the tests with '
      'COBALT_UPDATE_SNAPSHOTS=1, and commit it.',
    );
  }
  if (expected == actual) return;

  fail(
    'The graph no longer matches $path:\n\n'
    '${_diff(expected.split('\n'), actual.split('\n'))}\n'
    'If the change is intended, rewrite the snapshot by running the tests '
    'with COBALT_UPDATE_SNAPSHOTS=1, and commit it.',
  );
}

/// A line diff, `-` for what the snapshot has and `+` for what the graph has
/// now, with unchanged lines kept for context.
///
/// A plain longest-common-subsequence table: a graph is dozens of lines, not
/// thousands, and a readable diff is worth more here than a fast one.
String _diff(List<String> before, List<String> after) {
  final common = List.generate(
    before.length + 1,
    (_) => List.filled(after.length + 1, 0),
  );
  for (var i = before.length - 1; i >= 0; i--) {
    for (var j = after.length - 1; j >= 0; j--) {
      common[i][j] = before[i] == after[j]
          ? common[i + 1][j + 1] + 1
          : (common[i + 1][j] > common[i][j + 1]
                ? common[i + 1][j]
                : common[i][j + 1]);
    }
  }

  final out = <String>[];
  var i = 0;
  var j = 0;
  while (i < before.length && j < after.length) {
    if (before[i] == after[j]) {
      out.add('  ${before[i]}');
      i++;
      j++;
    } else if (common[i + 1][j] >= common[i][j + 1]) {
      out.add('- ${before[i++]}');
    } else {
      out.add('+ ${after[j++]}');
    }
  }
  while (i < before.length) {
    out.add('- ${before[i++]}');
  }
  while (j < after.length) {
    out.add('+ ${after[j++]}');
  }
  // The trailing newline splits into an empty last line on both sides.
  while (out.isNotEmpty && out.last.trim().isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}
