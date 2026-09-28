import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

const _injectedMatcher = CobaltAnnotationMatcher('Injected');

/// Reports an injectable class with `@injected` fields that does not mix in
/// its generated `_$ClassName`.
///
/// Without the mixin the fields are never assigned and the class fails at
/// runtime with a `LateInitializationError` far from the actual mistake.
///
/// Only for a class the container registers or applies as a decorator. A
/// class that is neither gets no mixin written for it either, so telling it to mix one in would send you to
/// a name that does not exist — that case is
/// `cobalt_injected_field_needs_an_injectable`.
class MissingInjectionMixin extends AnalysisRule {
  /// Creates the rule.
  MissingInjectionMixin()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_missing_injection_mixin',
    "'{0}' has @injected fields but does not mix in '_\${0}'.",
    correctionMessage: "Add 'with _\${0}' to the class and run build_runner.",
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) => registry.addClassDeclaration(this, _Visitor(this));
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  static const _parser = CobaltInjectableParser();
  static const _decorators = CobaltDecoratorParser();

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null) return;
    if (!_parser.declares(element) && !_decorators.declares(element)) return;

    final hasInjectedFields = element.fields.any(
      (field) => _injectedMatcher.matches(field),
    );
    if (!hasInjectedFields) return;

    final name = node.namePart.typeName.lexeme;
    final expected = '_\$$name';
    final mixedIn =
        node.withClause?.mixinTypes.any(
          (type) => type.name.lexeme == expected,
        ) ??
        false;

    if (!mixedIn) rule.reportAtNode(node.namePart, arguments: [name]);
  }
}
