// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'cobalt_inspector_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class CobaltInspectorL10nZh extends CobaltInspectorL10n {
  CobaltInspectorL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get inspectorTitle => 'Cobalt · 检查器';

  @override
  String get pauseTooltip => '暂停刷新';

  @override
  String get resumeTooltip => '继续跟踪依赖图';

  @override
  String get clearTooltip => '清除已记录的内容';

  @override
  String get tabTree => '作用域树';

  @override
  String get tabBuilt => '已构建';

  @override
  String get tabLog => '日志';

  @override
  String get logSearchHint => '按消息、作用域或键过滤';

  @override
  String get logEmpty => '尚无任何上报';

  @override
  String get logNoMatch => '没有匹配项';

  @override
  String get filterAll => '全部';

  @override
  String get familyScope => '作用域';

  @override
  String get familyStartup => '启动';

  @override
  String get familyInstance => '实例';

  @override
  String get familyFailure => '失败';

  @override
  String get treeSearchHint => '过滤注册项';

  @override
  String get collapseAll => '全部折叠';

  @override
  String get expandAll => '全部展开';

  @override
  String get treeNothingRegistered => '没有注册项';

  @override
  String get treeNoMatch => '没有匹配项';

  @override
  String get groupingFlat => '平铺';

  @override
  String get groupingByScope => '按作用域';

  @override
  String get groupingByLifetime => '按生命周期';

  @override
  String get builtEmpty => '尚未构建任何实例';

  @override
  String builtWhere(String scope, String ownership) {
    return '在 “$scope” · $ownership';
  }

  @override
  String get ownedByScope => '随作用域一起释放';

  @override
  String get ownedByCaller => '由调用方持有';

  @override
  String get lifetimeGone => '已消失';

  @override
  String get badgeOverridden => '已覆盖';

  @override
  String get badgeDecorated => '已装饰';

  @override
  String get copyRecord => '复制这条记录';

  @override
  String get recordCopied => '已复制记录';

  @override
  String get fieldLevel => '级别';

  @override
  String get fieldScope => '作用域';

  @override
  String get fieldKey => '键';

  @override
  String get fieldLifetime => '生命周期';

  @override
  String get fieldRetained => '是否保留';

  @override
  String get fieldError => '错误';

  @override
  String get fieldStack => '堆栈';

  @override
  String get fieldStructured => '结构化';

  @override
  String get factOwnedBy => '所属作用域';

  @override
  String get factReached => '可见方式';

  @override
  String get reachedInherited => '继承自上层作用域';

  @override
  String get reachedHere => '注册在此作用域';

  @override
  String get factReplaced => '替换';

  @override
  String get replacedByOverride => '被覆盖替换——真实注册已跳过';

  @override
  String get factDecoratedBy => '装饰器';

  @override
  String get factTornDown => '随作用域一起释放';

  @override
  String get tornDownYes => '是';

  @override
  String get tornDownNo => '否，由调用方持有';

  @override
  String get tornDownUnknown => '未知';

  @override
  String get factBuilt => '已构建';

  @override
  String get factFailed => '失败';

  @override
  String get buildItTitle => '立即构建';

  @override
  String get buildItSubtitle => '会真正创建实例并写入日志 —— 这会改变你正在观察的依赖图';

  @override
  String get notBuildable => '需要参数，无法从这里构建';

  @override
  String nodeCounts(int registrations, int children) {
    String _temp0 = intl.Intl.pluralLogic(
      children,
      locale: localeName,
      other: '$children 个子作用域',
    );
    return '$registrations 个注册 · $_temp0';
  }
}
