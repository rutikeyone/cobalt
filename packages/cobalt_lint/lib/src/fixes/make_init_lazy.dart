import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// Makes an `@CobaltInit` class that waits for a lazy registration lazy too,
/// by replacing its `dependsOn: [...]` with `lazy: true`.
///
/// Replaced rather than kept: the parser refuses `lazy` together with
/// `dependsOn`, because a lazy class is built by the first `getAsync`, which
/// awaits whatever it asks for, and `dependsOn` only orders `init()`.
///
/// Arguments are found by the label's token, not by their node class, which
/// is not the same class on every analyzer this package supports. Not offered
/// when the annotation already says `lazy:`; that is a choice to leave to the
/// author.
class MakeInitLazy extends ResolvedCorrectionProducer {
  /// Creates the producer for the diagnostic in [context].
  MakeInitLazy({required super.context});

  static const _kind = FixKind(
    'cobalt.fix.makeInitLazy',
    DartFixKindPriority.standard,
    "Replace 'dependsOn' with 'lazy: true'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final declaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (declaration == null) return;

    for (final annotation in declaration.metadata) {
      if (annotation.name.name.split('.').last != 'CobaltInit') continue;
      final arguments = annotation.arguments?.arguments;
      if (arguments == null) continue;

      AstNode? dependsOn;
      var saysLazy = false;
      for (final argument in arguments) {
        switch (_labelOf(argument)) {
          case 'dependsOn':
            dependsOn = argument;
          case 'lazy':
            saysLazy = true;
        }
      }
      if (dependsOn == null || saysLazy) continue;

      final range = SourceRange(dependsOn.offset, dependsOn.length);
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(range, 'lazy: true');
      });
      return;
    }
  }

  static String? _labelOf(AstNode argument) {
    final name = argument.beginToken;
    return name.next?.type == TokenType.COLON ? name.lexeme : null;
  }
}
