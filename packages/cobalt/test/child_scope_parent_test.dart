import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class Session {}

final class Screen {}

final class SessionScope extends CobaltChildScopeBuilder {
  const SessionScope();

  @override
  Type get marker => Session;

  @override
  void build(CobaltScope scope) {}
}

final class ScreenScope extends CobaltChildScopeBuilder {
  const ScreenScope();

  @override
  Type get marker => Screen;

  @override
  Type? get parent => Session;

  @override
  void build(CobaltScope scope) {}
}

final class _Mismatches extends CobaltObserver {
  final seen = <String>[];

  @override
  void onScopeParentMismatch(
    CobaltScopeRef scope, {
    required Type marker,
    required Type declaredParent,
  }) => seen.add('${scope.name}: $marker under $declaredParent');
}

final class _Recorded extends CobaltRecordingObserver {
  final records = <CobaltLogRecord>[];

  @override
  void onRecord(CobaltLogRecord record) => records.add(record);
}

void main() {
  late _Mismatches mismatches;
  late CobaltScope app;

  setUp(() {
    mismatches = _Mismatches();
    app = cobaltTestRoot(name: 'app', observers: [mismatches]);
  });

  tearDown(() => app.dispose());

  test('a child opened under its declared parent is quiet', () async {
    final session = await app.open('session', const SessionScope());
    await session.open('screen', const ScreenScope());

    expect(mismatches.seen, isEmpty);
  });

  test('a child opened under something else is reported', () async {
    await app.open('screen', const ScreenScope());

    expect(mismatches.seen, ['screen: Screen under Session']);
  });

  test('a scope in between does not hide the declared parent', () async {
    final session = await app.open('session', const SessionScope());
    final between = session.push('tabs');
    await between.open('screen', const ScreenScope());

    expect(mismatches.seen, isEmpty);
  });

  test('a child declared under the root opens anywhere', () async {
    final session = await app.open('session', const SessionScope());
    await session.open('nested session', const SessionScope());

    expect(mismatches.seen, isEmpty);
  });

  test('the log records it as a warning', () async {
    final recorded = _Recorded();
    final root = cobaltTestRoot(name: 'app', observers: [recorded]);
    addTearDown(root.dispose);

    await root.open('screen', const ScreenScope());

    final record = recorded.records.singleWhere(
      (record) => record.kind == CobaltEventKind.scopeParentMismatch,
    );
    expect(record.level, CobaltLogLevel.warning);
    expect(record.message, contains('declared under Session'));
  });
}
