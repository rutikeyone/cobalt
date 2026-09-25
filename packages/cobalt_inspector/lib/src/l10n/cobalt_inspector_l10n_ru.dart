// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'cobalt_inspector_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class CobaltInspectorL10nRu extends CobaltInspectorL10n {
  CobaltInspectorL10nRu([String locale = 'ru']) : super(locale);

  @override
  String get inspectorTitle => 'Cobalt · инспектор';

  @override
  String get pauseTooltip => 'остановить обновление';

  @override
  String get resumeTooltip => 'снова следить за графом';

  @override
  String get clearTooltip => 'забыть записанное';

  @override
  String get tabTree => 'Дерево';

  @override
  String get tabBuilt => 'Создано';

  @override
  String get tabLog => 'Журнал';

  @override
  String get logSearchHint => 'фильтр по сообщению, скоупу или ключу';

  @override
  String get logEmpty => 'Пока ничего не сообщено';

  @override
  String get logNoMatch => 'Ничего не совпало';

  @override
  String get filterAll => 'все';

  @override
  String get familyScope => 'скоупы';

  @override
  String get familyStartup => 'старт';

  @override
  String get familyInstance => 'объекты';

  @override
  String get familyFailure => 'сбои';

  @override
  String get treeSearchHint => 'фильтр регистраций';

  @override
  String get collapseAll => 'свернуть всё';

  @override
  String get expandAll => 'развернуть всё';

  @override
  String get treeNothingRegistered => 'ничего не зарегистрировано';

  @override
  String get treeNoMatch => 'ничего не совпало';

  @override
  String get groupingFlat => 'списком';

  @override
  String get groupingByScope => 'по скоупам';

  @override
  String get groupingByLifetime => 'по времени жизни';

  @override
  String get builtEmpty => 'Пока ничего не создано';

  @override
  String builtWhere(String scope, String ownership) {
    return 'в «$scope» · $ownership';
  }

  @override
  String get ownedByScope => 'разбирается вместе со скоупом';

  @override
  String get ownedByCaller => 'принадлежит вызывающему';

  @override
  String get lifetimeGone => 'исчезла';

  @override
  String get badgeOverridden => 'подменена';

  @override
  String get badgeDecorated => 'обёрнута';

  @override
  String get copyRecord => 'скопировать запись';

  @override
  String get recordCopied => 'Запись скопирована';

  @override
  String get fieldLevel => 'уровень';

  @override
  String get fieldScope => 'скоуп';

  @override
  String get fieldKey => 'ключ';

  @override
  String get fieldLifetime => 'время жизни';

  @override
  String get fieldRetained => 'удерживается';

  @override
  String get fieldError => 'ошибка';

  @override
  String get fieldStack => 'стек';

  @override
  String get fieldStructured => 'структурно';

  @override
  String get factOwnedBy => 'Владелец';

  @override
  String get factReached => 'Доступ';

  @override
  String get reachedInherited => 'унаследована от предка';

  @override
  String get reachedHere => 'зарегистрирована в этом скоупе';

  @override
  String get factReplaced => 'Подмена';

  @override
  String get replacedByOverride => 'override — настоящая регистрация пропущена';

  @override
  String get factDecoratedBy => 'Декораторы';

  @override
  String get factTornDown => 'Разбирается вместе со скоупом';

  @override
  String get tornDownYes => 'да';

  @override
  String get tornDownNo => 'нет, владеет вызывающий';

  @override
  String get tornDownUnknown => 'неизвестно';

  @override
  String get factBuilt => 'Создано';

  @override
  String get factFailed => 'Не удалось';

  @override
  String get buildItTitle => 'Создать сейчас';

  @override
  String get buildItSubtitle =>
      'Создаёт объект по-настоящему и пишет об этом в журнал — это меняет граф, на который вы смотрите';

  @override
  String get notBuildable =>
      'Принимает аргумент, поэтому отсюда его не создать';

  @override
  String nodeCounts(int registrations, int children) {
    String _temp0 = intl.Intl.pluralLogic(
      children,
      locale: localeName,
      other: '$children дочерних',
      many: '$children дочерних',
      few: '$children дочерних',
      one: '$children дочерний',
    );
    return '$registrations рег. · $_temp0';
  }
}
