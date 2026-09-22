// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'codegen_basics_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class CodegenBasicsL10nRu extends CodegenBasicsL10n {
  CodegenBasicsL10nRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Cobalt: основы кодогенерации';

  @override
  String environment(String name) {
    return 'окружение: $name';
  }

  @override
  String greeting(String name, String environment) {
    return 'привет, $name, из окружения $environment';
  }

  @override
  String get increment => 'увеличить';

  @override
  String get leaderboardLoading => 'загружаем таблицу лидеров…';

  @override
  String leaderboardReady(int entries) {
    return 'таблица лидеров готова, записей: $entries';
  }
}
