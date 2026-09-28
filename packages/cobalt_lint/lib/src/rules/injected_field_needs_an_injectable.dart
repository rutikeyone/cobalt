import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

const _injectedMatcher = CobaltAnnotationMatcher('Injected');

/// Reports `@injected` fields on a class the container never registers.
///
/// `@injected` is filled by the generated `_$ClassName` mixin, and that mixin
/// is written only for a class the container knows about — a registration or
/// an `@CobaltDecorates` class. On a class that says
/// nothing, `@injected` does nothing at all — the field stays unassigned and
/// throws a `LateInitializationError` the first time it is read.
///
/// Reported separately from `cobalt_missing_injection_mixin` because the fix is
/// different: there is no mixin to add here, and asking for one sends you to a
/// name the generator will never write.
class InjectedFieldNeedsAnInjectable extends AnalysisRule {
  /// Creates the rule.
  InjectedFieldNeedsAnInjectable()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_injected_field_needs_an_injectable',
    "'{0}' has @injected fields but nothing registers it.",
    correctionMessage:
        'Annotate the class with @CobaltInject, @CobaltInit or @CobaltDecorates '
        'so the mixin that fills the fields is generated, or drop @injected and '
        'take the dependency through the constructor.',
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
    if (_parser.declares(element) || _decorators.declares(element)) return;

    final hasInjectedFields = element.fields.any(
      (field) => _injectedMatcher.matches(field),
    );
    if (!hasInjectedFields) return;

    rule.reportAtNode(
      node.namePart,
      arguments: [node.namePart.typeName.lexeme],
    );
  }
}
