import 'package:cobalt_inspector/src/l10n/cobalt_inspector_l10n.dart';

extension StartupStrings on CobaltInspectorL10n {
  String startupTook(String time) => switch (localeName) {
    'ru' => 'Старт: $time',
    'zh' => '启动：$time',
    'ko' => '시작: $time',
    _ => 'Startup: $time',
  };

  String get startupSteps => switch (localeName) {
    'ru' => 'Шаги bootstrap',
    'zh' => 'bootstrap 步骤',
    'ko' => 'bootstrap 단계',
    _ => 'Bootstrap steps',
  };

  String get startupWaits => switch (localeName) {
    'ru' => 'Дольше всех ждали зависимости',
    'zh' => '等待依赖最久的',
    'ko' => '의존성을 가장 오래 기다린 것',
    _ => 'Waited longest for dependencies',
  };

  String waitedOf(String waited, String took) => switch (localeName) {
    'ru' => '$waited из $took',
    'zh' => '$took 中的 $waited',
    'ko' => '$took 중 $waited',
    _ => '$waited of $took',
  };
}
