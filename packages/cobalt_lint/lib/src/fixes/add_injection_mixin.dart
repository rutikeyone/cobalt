import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// Mixes the generated `_$ClassName` into a class with `@injected` fields,
/// with the class type parameters passed on for a generic one, and fixes a
/// `with _$Cache` that leaves them out.
///
/// Appended to an existing `with` clause, or written after the `extends`
/// clause, or after the name and type parameters when there is neither, which
/// is where Dart wants it: before any `implements`. The mixin may not exist
/// yet; `build_runner` writes it, as the diagnostic says.
class AddInjectionMixin extends ResolvedCorrectionProducer {
  /// Creates the producer for the diagnostic in [context].
  AddInjectionMixin({required super.context});

  static const _kind = FixKind(
    'cobalt.fix.addInjectionMixin',
    DartFixKindPriority.standard,
    "Mix in '{0}'",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String>? get fixArguments {
    final declaration = node.thisOrAncestorOfType<ClassDeclaration>();
    return declaration == null ? null : [_mixinOf(declaration)];
  }

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final declaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (declaration == null) return;

    final mixin = _mixinOf(declaration);
    final withClause = declaration.withClause;
    final name = '_\$${declaration.namePart.typeName.lexeme}';
    final existing = withClause?.mixinTypes
        .where((type) => type.name.lexeme == name)
        .firstOrNull;
    final part = _partOf(unitResult);
    final needsPart = part != null && !_declaresPart(unitResult.unit, part);
    final mixedIn = existing != null && existing.toSource() == mixin;
    if (mixedIn && !needsPart) return;

    await builder.addDartFileEdit(file, (builder) {
      if (needsPart) {
        final directives = unitResult.unit.directives;
        final eol = defaultEol;
        if (directives.isEmpty) {
          builder.addSimpleInsertion(0, "part '$part';$eol$eol");
        } else {
          builder.addSimpleInsertion(
            directives.last.end,
            "$eol${eol}part '$part';",
          );
        }
      }
      if (mixedIn) return;
      if (existing != null) {
        builder.addSimpleReplacement(
          SourceRange(existing.offset, existing.length),
          mixin,
        );
      } else if (withClause != null) {
        builder.addSimpleInsertion(withClause.end, ', $mixin');
      } else {
        final after = declaration.extendsClause ?? declaration.namePart;
        builder.addSimpleInsertion(after.end, ' with $mixin');
      }
    });
  }

  static String? _partOf(ResolvedUnitResult unit) {
    final name = unit.uri.pathSegments.lastOrNull;
    if (name == null || !name.endsWith('.dart')) return null;
    return '${name.substring(0, name.length - '.dart'.length)}.g.dart';
  }

  static bool _declaresPart(CompilationUnit unit, String part) => unit
      .directives
      .whereType<PartDirective>()
      .any((directive) => directive.uri.stringValue == part);

  static String _mixinOf(ClassDeclaration declaration) {
    final name = '_\$${declaration.namePart.typeName.lexeme}';
    final parameters = [
      for (final parameter
          in declaration.declaredFragment?.element.typeParameters ??
              const <TypeParameterElement>[])
        parameter.displayName,
    ];
    return parameters.isEmpty ? name : '$name<${parameters.join(', ')}>';
  }
}
