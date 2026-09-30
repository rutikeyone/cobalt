// CobaltScope's debug* members are @experimental — outside semver, which newer
// analyzers flag on every use from another package. Reading the graph through
// them is what this file is for.
// ignore_for_file: experimental_member_use

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/src/graph_facts.dart';

/// What [scope] and the scopes below it register, as a Mermaid flowchart.
///
/// The same facts as `describeGraph`, drawn: each scope a subgraph nested as
/// the tree is, each registration a box with its kind and markers, a scope's
/// hooks and what it adopted rounded boxes of their own. Paste it into a fenced `mermaid` block
/// and GitHub, GitLab and most Markdown editors render it:
///
/// ````markdown
/// ```mermaid
/// flowchart TD
///   subgraph s0["scope #quot;app#quot;"]
///     direction TB
///     s0_k0["ApiClient<br/>lazySingleton<br/>decorated: Retrying → Logging"]
///   end
/// ```
/// ````
///
/// Nothing is built, and the output is stable — sorted as `describeGraph`
/// sorts — so a diagram kept in a document diffs like the text snapshot.
String describeGraphMermaid(CobaltScope scope) {
  final lines = <String>['flowchart TD'];
  var next = 0;

  void describe(CobaltScope scope, String indent) {
    final id = 's${next++}';
    lines
      ..add('$indent  subgraph $id["${_escape('scope "${scope.name}"')}"]')
      ..add('$indent    direction TB');
    final hooks = scope.debugHooks;
    if (hooks.isNotEmpty) {
      lines.add(
        '$indent    ${id}_hooks(["${_escape('hooks: ${hooks.join(', ')}')}"])',
      );
    }
    final adopted = scope.debugAdopted;
    if (adopted.isNotEmpty) {
      lines.add(
        '$indent    ${id}_adopted(["${_escape('adopted: ${adopted.join(', ')}')}"])',
      );
    }
    final keys = describedKeysOf(scope);
    for (final (index, key) in keys.indexed) {
      final label = ['$key', ...factsOf(scope, key)].map(_escape).join('<br/>');
      lines.add('$indent    ${id}_k$index["$label"]');
    }
    if (hooks.isEmpty &&
        adopted.isEmpty &&
        keys.isEmpty &&
        scope.children.isEmpty) {
      // Mermaid draws an empty subgraph poorly, or not at all.
      lines.add('$indent    ${id}_empty["nothing registered"]');
    }
    for (final child in scope.children) {
      describe(child, '$indent  ');
    }
    lines.add('$indent  end');
  }

  describe(scope, '');
  return '${lines.join('\n')}\n';
}

/// Mermaid's entity codes for what would otherwise end a label or read as
/// markup: quotes, and the angle brackets of a generic type.
String _escape(String text) => text
    .replaceAll('"', '#quot;')
    .replaceAll('<', '#lt;')
    .replaceAll('>', '#gt;');
