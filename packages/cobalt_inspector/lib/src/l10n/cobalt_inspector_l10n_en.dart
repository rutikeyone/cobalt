// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'cobalt_inspector_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CobaltInspectorL10nEn extends CobaltInspectorL10n {
  CobaltInspectorL10nEn([String locale = 'en']) : super(locale);

  @override
  String get inspectorTitle => 'Cobalt · inspector';

  @override
  String get pauseTooltip => 'hold the view still';

  @override
  String get resumeTooltip => 'follow the graph again';

  @override
  String get clearTooltip => 'forget what has been recorded';

  @override
  String get tabTree => 'Tree';

  @override
  String get tabBuilt => 'Built';

  @override
  String get tabLog => 'Log';

  @override
  String get logSearchHint => 'filter by message, scope or key';

  @override
  String get logEmpty => 'Nothing reported yet';

  @override
  String get logNoMatch => 'Nothing matches that';

  @override
  String get filterAll => 'all';

  @override
  String get familyScope => 'scope';

  @override
  String get familyStartup => 'startup';

  @override
  String get familyInstance => 'instance';

  @override
  String get familyFailure => 'failure';

  @override
  String get treeSearchHint => 'filter registrations';

  @override
  String get collapseAll => 'collapse all';

  @override
  String get expandAll => 'expand all';

  @override
  String get treeNothingRegistered => 'nothing registered';

  @override
  String get treeNoMatch => 'nothing matches';

  @override
  String get groupingFlat => 'flat';

  @override
  String get groupingByScope => 'by scope';

  @override
  String get groupingByLifetime => 'by lifetime';

  @override
  String get builtEmpty => 'Nothing built yet';

  @override
  String builtWhere(String scope, String ownership) {
    return 'in \"$scope\" · $ownership';
  }

  @override
  String get ownedByScope => 'torn down with the scope';

  @override
  String get ownedByCaller => 'caller owns it';

  @override
  String get lifetimeGone => 'gone';

  @override
  String get badgeOverridden => 'overridden';

  @override
  String get badgeDecorated => 'decorated';

  @override
  String get copyRecord => 'copy this record';

  @override
  String get recordCopied => 'Record copied';

  @override
  String get fieldLevel => 'level';

  @override
  String get fieldScope => 'scope';

  @override
  String get fieldKey => 'key';

  @override
  String get fieldLifetime => 'lifetime';

  @override
  String get fieldRetained => 'retained';

  @override
  String get fieldError => 'error';

  @override
  String get fieldStack => 'stack';

  @override
  String get fieldStructured => 'structured';

  @override
  String get factOwnedBy => 'Owned by';

  @override
  String get factReached => 'Reached';

  @override
  String get reachedInherited => 'inherited from an ancestor';

  @override
  String get reachedHere => 'registered in this scope';

  @override
  String get factReplaced => 'Replaced';

  @override
  String get replacedByOverride =>
      'by an override — the real registration was skipped';

  @override
  String get factDecoratedBy => 'Decorated by';

  @override
  String get factTornDown => 'Torn down with the scope';

  @override
  String get tornDownYes => 'yes';

  @override
  String get tornDownNo => 'no, the caller owns it';

  @override
  String get tornDownUnknown => 'unknown';

  @override
  String get factBuilt => 'Built';

  @override
  String get factFailed => 'Failed';

  @override
  String get buildItTitle => 'Build it now';

  @override
  String get buildItSubtitle =>
      'Creates the instance for real and logs it — this changes the graph you are looking at';

  @override
  String get notBuildable =>
      'Takes a parameter, so it cannot be built from here';

  @override
  String nodeCounts(int registrations, int children) {
    String _temp0 = intl.Intl.pluralLogic(
      children,
      locale: localeName,
      other: '$children children',
      one: '1 child',
    );
    return '$registrations reg · $_temp0';
  }
}
