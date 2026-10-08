import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';

/// What `registerFixForRule` takes: a producer's constructor tear-off.
typedef FixGenerator =
    CorrectionProducer<ParsedUnitResult> Function({
      required CorrectionProducerContext context,
    });

/// Runs a quick fix the way the analysis server does, without a server.
extension FixSupport on AnalysisRuleTest {
  /// The source after the fix from [generator] is applied to the single
  /// diagnostic [rule] reports in [code], or `null` when the fix offers no
  /// change there.
  Future<String?> fixed(String code, FixGenerator generator) async {
    testFile.writeAsStringSync(code);
    final unit = await resolveFile(testFile.path);
    final diagnostic = unit.diagnostics.singleWhere(
      (diagnostic) => rule.diagnosticCodes.contains(diagnostic.diagnosticCode),
    );
    final library =
        await unit.session.getResolvedLibrary(unit.path)
            as ResolvedLibraryResult;

    final producer = generator(
      context: CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: unit,
        diagnostic: diagnostic,
        selectionOffset: diagnostic.offset,
        selectionLength: diagnostic.length,
      ),
    );
    if (producer.fixKind == null) return null;

    final builder = ChangeBuilder(session: unit.session);
    await producer.compute(builder);

    final edits = builder.sourceChange.edits;
    if (edits.isEmpty) return null;
    expect(edits.map((edit) => edit.file), [unit.path]);
    return SourceEdit.applySequence(code, edits.single.edits);
  }
}
