import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// Reports a `CobaltOverride` or `CobaltParamOverride` written without its
/// type argument.
///
/// The type argument is the key the override replaces, and Dart infers it
/// from context rather than from intent: inside an `overrides:` list it
/// becomes `Object`, and on its own it becomes the replacement's type —
/// `FixedClock`, not `Clock`. Either way the override replaces nothing. The
/// scope refuses both at run time; this moves the refusal into the editor.
class OverrideNeedsTypeArgument extends AnalysisRule {
  /// Creates the rule.
  OverrideNeedsTypeArgument()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_override_needs_type_argument',
    "'{0}' has no type argument, so Dart infers the key it replaces.",
    correctionMessage:
        'Name the registered type, as in {0}<Clock>.value(...): inferred, it '
        'becomes Object inside a list and the replacement type elsewhere.',
  );

  static const _overrides = {'CobaltOverride', 'CobaltParamOverride'};

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) => registry.addInstanceCreationExpression(this, _Visitor(this));
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final written = node.constructorName.type;
    if (written.typeArguments != null) return;

    final type = node.staticType;
    if (type is! InterfaceType) return;
    final element = type.element;
    final name = element.name;
    if (name == null || !OverrideNeedsTypeArgument._overrides.contains(name)) {
      return;
    }
    final uri = element.library.uri;
    if (uri.scheme != 'package' || uri.pathSegments.first != 'cobalt') return;

    rule.reportAtNode(written, arguments: [name]);
  }
}
