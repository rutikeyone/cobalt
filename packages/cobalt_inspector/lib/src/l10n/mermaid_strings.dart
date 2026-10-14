import 'package:cobalt_inspector/src/l10n/cobalt_inspector_l10n.dart';

extension MermaidStrings on CobaltInspectorL10n {
  String get copyMermaid => switch (localeName) {
    'ru' => 'Скопировать граф как Mermaid',
    'zh' => '复制为 Mermaid 图',
    'ko' => '그래프를 Mermaid로 복사',
    _ => 'Copy the graph as Mermaid',
  };

  String get mermaidCopied => switch (localeName) {
    'ru' => 'Граф скопирован как Mermaid',
    'zh' => '已复制为 Mermaid 图',
    'ko' => '그래프를 Mermaid로 복사했습니다',
    _ => 'Graph copied as Mermaid',
  };
}
