// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'codegen_basics_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class CodegenBasicsL10nKo extends CodegenBasicsL10n {
  CodegenBasicsL10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Cobalt 코드 생성 기초';

  @override
  String environment(String name) {
    return '환경: $name';
  }

  @override
  String greeting(String name, String environment) {
    return '안녕하세요, $name. $environment에서 보냅니다';
  }

  @override
  String get increment => '증가';

  @override
  String get leaderboardLoading => '리더보드 불러오는 중…';

  @override
  String leaderboardReady(int entries) {
    return '리더보드 준비됨: 항목 $entries개';
  }
}
