import 'package:cobalt_inspector/src/l10n/cobalt_inspector_l10n.dart';

extension BuildTimeStrings on CobaltInspectorL10n {
  String withDependencies(String time) => switch (localeName) {
    'ru' => '$time с зависимостями',
    'zh' => '含依赖 $time',
    'ko' => '의존성 포함 $time',
    _ => '$time with dependencies',
  };

  String withoutDependencies(String time) => switch (localeName) {
    'ru' => '$time без зависимостей',
    'zh' => '不含依赖 $time',
    'ko' => '의존성 제외 $time',
    _ => '$time without its dependencies',
  };
}
