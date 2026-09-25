import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/registration_index.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Reports an `@CobaltInit(dependsOn: [...])` naming a lazy async
/// registration.
///
/// `dependsOn` orders phase 1, and a lazy registration is not built in
/// phase 1 — it waits for the first `getAsync`. There is nothing to wait for,
/// and the build refuses it; this is the same answer in the editor, read from
/// the package-wide [CobaltRegistrationIndex].
class DependsOnLazyRegistration extends AnalysisRule {
  /// Creates the rule.
  DependsOnLazyRegistration()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_depends_on_lazy_registration',
    "'{0}' waits for '{1}' in dependsOn, but '{1}' is lazy and is not built "
        'by init().',
    correctionMessage:
        "Make '{0}' lazy too with @CobaltInit(lazy: true), so its factory "
        "awaits '{1}', or drop lazy from '{1}'.",
  );

  final _cache = CobaltRegistrationIndexCache();

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) => registry.addClassDeclaration(this, _Visitor(this, context, _cache));
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context, this._cache);

  static const _parser = CobaltInjectableParser();

  final AnalysisRule rule;
  final RuleContext context;
  final CobaltRegistrationIndexCache _cache;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null || !_parser.declares(element)) return;

    final CobaltInjectableClass declaration;
    try {
      declaration = _parser.parseClass(element);
    } on CobaltParseError {
      return;
    }
    if (declaration.dependsOn.isEmpty) return;

    final index = _index();
    if (index == null || index.lazy.isEmpty) return;

    for (final waited in declaration.dependsOn) {
      if (!index.lazy.contains(waited.name)) continue;
      rule.reportAtNode(
        node.namePart,
        arguments: [declaration.label, waited.name],
      );
      return;
    }
  }

  CobaltRegistrationIndex? _index() {
    final root = context.package?.root;
    final session = context.libraryElement?.session;
    if (root == null || session == null) return null;
    return _cache.of(root, session);
  }
}
