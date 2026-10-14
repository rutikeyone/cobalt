import 'package:cobalt/cobalt.dart';

String graphMermaidOf(CobaltScope scope) {
  final lines = <String>['flowchart TD'];
  var next = 0;

  void describe(CobaltScope scope, String indent) {
    final id = 's${next++}';
    lines
      ..add('$indent  subgraph $id["${_escape('scope "${scope.name}"')}"]')
      ..add('$indent    direction TB');
    final hooks = scope.hooks;
    if (hooks.isNotEmpty) {
      lines.add(
        '$indent    ${id}_hooks(["${_escape('hooks: ${hooks.join(', ')}')}"])',
      );
    }
    final adopted = scope.adoptedTypes;
    if (adopted.isNotEmpty) {
      lines.add(
        '$indent    ${id}_adopted(["${_escape('adopted: ${adopted.join(', ')}')}"])',
      );
    }
    final keys = scope.keys.toList()..sort((a, b) => '$a'.compareTo('$b'));
    for (final (index, key) in keys.indexed) {
      final label = [
        '$key',
        ..._factsOf(scope, key),
      ].map(_escape).join('<br/>');
      lines.add('$indent    ${id}_k$index["$label"]');
    }
    if (hooks.isEmpty &&
        adopted.isEmpty &&
        keys.isEmpty &&
        scope.children.isEmpty) {
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

List<String> _factsOf(CobaltScope scope, CobaltKey key) {
  final info = scope.registrationOf(key);
  return [
    info?.kind.name ?? 'unknown',
    if (info?.implementation case final implementation?
        when implementation != '${key.type}')
      'as $implementation',
    if (scope.overriddenKeys.contains(key)) 'overridden',
    if (info?.decorators case final decorators? when decorators.isNotEmpty)
      'decorated: ${decorators.join(' → ')}',
  ];
}

String _escape(String text) => text
    .replaceAll('"', '#quot;')
    .replaceAll('<', '#lt;')
    .replaceAll('>', '#gt;');
