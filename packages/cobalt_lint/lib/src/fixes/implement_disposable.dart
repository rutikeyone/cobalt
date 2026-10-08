import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:cobalt_lint/src/class_members.dart';
import 'package:cobalt_lint/src/teardown_shape.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// Declares the interface that tells the scope to close a registration:
/// `Disposable`, or `AsyncDisposable` when its teardown returns a `Future`.
///
/// The teardown is the one the rule found. When it is not called `dispose`, a
/// `dispose` that delegates to it is added beside it, or at the end of the
/// class when it is inherited. `package:cobalt/cobalt.dart` is imported when
/// the interface is not visible yet.
///
/// Not offered when the teardown returns a `FutureOr`, which neither
/// interface's `dispose` accepts, or when the class already has a `dispose`
/// that is not the teardown and would clash with the one the fix adds.
class ImplementDisposable extends ResolvedCorrectionProducer {
  /// Creates the producer for the diagnostic in [context].
  ImplementDisposable({required super.context});

  static const _kind = FixKind(
    'cobalt.fix.implementDisposable',
    DartFixKindPriority.standard,
    "Implement '{0}'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String>? get fixArguments {
    final element = node
        .thisOrAncestorOfType<ClassDeclaration>()
        ?.declaredFragment
        ?.element;
    final teardown = element == null ? null : teardownMethodOf(element);
    if (element == null || teardown == null) return null;
    final returned = _methodOf(element, teardown)?.returnType;
    return [
      returned != null && returned.isDartAsyncFuture
          ? 'AsyncDisposable'
          : 'Disposable',
    ];
  }

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final declaration = node.thisOrAncestorOfType<ClassDeclaration>();
    final element = declaration?.declaredFragment?.element;
    if (declaration == null || element == null) return;

    final teardown = teardownMethodOf(element);
    if (teardown == null) return;
    final returned = _methodOf(element, teardown)?.returnType;
    if (returned == null || returned.isDartAsyncFutureOr) return;
    if (teardown != 'dispose' && _methodOf(element, 'dispose') != null) return;

    final isAsync = returned.isDartAsyncFuture;
    final interface = isAsync ? 'AsyncDisposable' : 'Disposable';
    final visible =
        unitResult.libraryFragment.scope.lookup(interface).getter != null;

    final implementsClause = declaration.implementsClause;
    final after =
        declaration.withClause ??
        declaration.extendsClause ??
        declaration.namePart;

    await builder.addDartFileEdit(file, (builder) {
      if (!visible) {
        builder.importLibrary(Uri.parse('package:cobalt/cobalt.dart'));
      }
      if (implementsClause != null) {
        builder.addSimpleInsertion(implementsClause.end, ', $interface');
      } else {
        builder.addSimpleInsertion(after.end, ' implements $interface');
      }
      if (teardown != 'dispose') {
        _addDelegate(builder, declaration, teardown, isAsync);
      }
    });
  }

  void _addDelegate(
    FileEditBuilder builder,
    ClassDeclaration declaration,
    String teardown,
    bool isAsync,
  ) {
    final body = declaration.body;
    if (body is! BlockClassBody) return;

    final members = membersOf(declaration).toList();
    final eol = defaultEol;
    final classIndent = utils.getLinePrefix(
      declaration.firstTokenAfterCommentAndMetadata.offset,
    );
    final indent = members.isEmpty
        ? '$classIndent${utils.oneIndent}'
        : utils.getLinePrefix(members.first.offset);
    final delegate =
        '$indent@override$eol'
        '$indent${isAsync ? 'Future<void>' : 'void'} dispose() => '
        '$teardown();';

    if (members.isEmpty) {
      final inside = utils.getText(
        body.leftBracket.end,
        body.rightBracket.offset - body.leftBracket.end,
      );
      if (inside.trim().isEmpty) {
        builder.addSimpleReplacement(
          SourceRange(body.leftBracket.end, inside.length),
          '$eol$delegate$eol$classIndent',
        );
      } else {
        builder.addSimpleInsertion(body.rightBracket.offset, '$delegate$eol');
      }
      return;
    }

    final anchor =
        members
            .whereType<MethodDeclaration>()
            .where((member) => member.name.lexeme == teardown)
            .firstOrNull ??
        members.last;
    builder.addSimpleInsertion(anchor.end, '$eol$eol$delegate');
  }

  static MethodElement? _methodOf(InterfaceElement element, String name) =>
      element.methods.where((it) => it.name == name).firstOrNull ??
      element.allSupertypes
          .expand((supertype) => supertype.methods)
          .where((it) => it.name == name)
          .firstOrNull;
}
