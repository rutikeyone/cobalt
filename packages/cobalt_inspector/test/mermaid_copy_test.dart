import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_inspector/cobalt_inspector.dart';
import 'package:cobalt_inspector/src/graph_mermaid.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late CobaltInspectorLog log;

  setUp(() {
    clocksBuilt = 0;
    log = CobaltInspectorLog();
  });

  CobaltScope graph() {
    final scope = buildGraph(log);
    scope
        .push('session')
        .registerLazySingleton<Ticket>(FnFactory((_) => Ticket('open')));
    return scope;
  }

  test('draws what describeGraphMermaid in cobalt_test draws', () {
    final scope = graph();

    expect(graphMermaidOf(scope), describeGraphMermaid(scope));
  });

  testWidgets('the tree copies the graph as Mermaid', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final scope = graph();
    await tester.pumpWidget(inspectorUnderTest(scope, log));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('copy-mermaid')));
    await tester.pumpAndSettle();

    expect(copied, [describeGraphMermaid(scope)]);
    expect(find.text('Graph copied as Mermaid'), findsOneWidget);
  });
}
