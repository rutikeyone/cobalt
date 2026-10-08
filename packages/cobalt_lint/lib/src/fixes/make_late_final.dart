import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// Declares an `@injected` field `late final`.
///
/// Offered only where the result is the field the mixin expects: not on a
/// static, abstract, external or const field, and not on one with an
/// initializer, which the mixin could never assign and which the fix would
/// otherwise have to delete.
class MakeLateFinal extends ResolvedCorrectionProducer {
  /// Creates the producer for the diagnostic in [context].
  MakeLateFinal({required super.context});

  static const _kind = FixKind(
    'cobalt.fix.makeLateFinal',
    DartFixKindPriority.standard,
    "Make the field 'late final'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final declaration = node.thisOrAncestorOfType<FieldDeclaration>();
    if (declaration == null ||
        declaration.isStatic ||
        declaration.abstractKeyword != null ||
        declaration.externalKeyword != null) {
      return;
    }

    final fields = declaration.fields;
    if (fields.isConst || (fields.isLate && fields.isFinal)) return;
    if (fields.variables.any((variable) => variable.initializer != null)) {
      return;
    }

    final keyword = fields.keyword;
    await builder.addDartFileEdit(file, (builder) {
      if (keyword == null) {
        final start = fields.type?.offset ?? fields.variables.first.offset;
        builder.addSimpleInsertion(
          start,
          fields.isLate ? 'final ' : 'late final ',
        );
      } else if (!fields.isFinal) {
        builder.addSimpleReplacement(
          SourceRange(keyword.offset, keyword.length),
          fields.isLate ? 'final' : 'late final',
        );
      } else {
        builder.addSimpleInsertion(keyword.offset, 'late ');
      }
    });
  }
}
