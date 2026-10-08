import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// Registers a class the container does not know with `@cobaltInject`.
///
/// Shared by the rules whose diagnostic is an annotation that does nothing on
/// an unregistered class: `@injected`, `@CobaltEnvironment` and
/// `@CobaltParam`. Written on its own line right above the class keyword and
/// its modifiers, after any annotations and doc comment already there.
///
/// Offered only where `cobaltInject` already names the Cobalt constant without
/// a prefix, so the fix never has to guess how the library spells its import,
/// and never on an abstract class, which the container cannot construct.
class AddCobaltInject extends ResolvedCorrectionProducer {
  /// Creates the producer for the diagnostic in [context].
  AddCobaltInject({required super.context});

  static const _kind = FixKind(
    'cobalt.fix.addCobaltInject',
    DartFixKindPriority.standard,
    "Register the class with '@cobaltInject'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final declaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (declaration == null || declaration.abstractKeyword != null) return;

    final element = declaration.declaredFragment?.element;
    if (element == null || injectMatcher.matches(element)) return;
    if (!_annotationIsVisible()) return;

    final offset = declaration.firstTokenAfterCommentAndMetadata.offset;
    final indent = utils.getLinePrefix(offset);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(offset, '@cobaltInject$defaultEol$indent');
    });
  }

  bool _annotationIsVisible() {
    final found = unitResult.libraryFragment.scope
        .lookup('cobaltInject')
        .getter;
    final uri = found?.library?.uri;
    return uri != null &&
        uri.scheme == 'package' &&
        uri.pathSegments.first == 'cobalt_annotations';
  }
}
