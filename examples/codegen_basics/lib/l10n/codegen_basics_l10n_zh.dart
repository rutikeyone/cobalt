// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'codegen_basics_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class CodegenBasicsL10nZh extends CodegenBasicsL10n {
  CodegenBasicsL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Cobalt 代码生成基础';

  @override
  String environment(String name) {
    return '运行环境：$name';
  }

  @override
  String greeting(String name, String environment) {
    return '你好，$name，来自 $environment';
  }

  @override
  String get increment => '增加';

  @override
  String get leaderboardLoading => '正在加载排行榜…';

  @override
  String leaderboardReady(int entries) {
    return '排行榜已就绪：$entries 条记录';
  }
}
