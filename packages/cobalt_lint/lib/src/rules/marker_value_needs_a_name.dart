import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/class_members.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

class MarkerValueNeedsAName extends AnalysisRule {
  MarkerValueNeedsAName()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  static const code = LintCode(
    'cobalt_marker_value_needs_a_name',
    "'{0}' is registered by the scope under the bare type {1}.",
    correctionMessage:
        "Name it, as in @Named('{0}') this.{0}. Unnamed, it is what every "
        'class in the scope that asks for a {1} receives, and it hides an '
        'unnamed {1} the root registers.',
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

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null || !childScopeMatcher.matches(element)) return;

    for (final parameter
        in publicConstructorParametersOf(node) ?? const <FormalParameter>[]) {
      final value = parameter.declaredFragment?.element;
      if (value == null || !_isPrimitive(value.type) || _isNamed(value)) {
        continue;
      }
      rule.reportAtNode(
        parameter,
        arguments: [value.displayName, value.type.getDisplayString()],
      );
    }
  }

  bool _isPrimitive(DartType type) =>
      type.isDartCoreString ||
      type.isDartCoreInt ||
      type.isDartCoreDouble ||
      type.isDartCoreNum ||
      type.isDartCoreBool;

  bool _isNamed(FormalParameterElement value) {
    if (namedMatcher.matches(value)) return true;
    if (value is! FieldFormalParameterElement) return false;
    final field = value.field;
    return field != null && namedMatcher.matches(field);
  }
}
