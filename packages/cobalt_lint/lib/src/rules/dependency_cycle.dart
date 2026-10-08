import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/registration_index.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Reports an injectable class that depends, eventually, on itself.
///
/// The build already rejects such a graph — `layeredTopologicalSort` cannot
/// drain it and names the loop. This is the same answer earlier, in the
/// editor, from a coarser view: see [CobaltRegistrationIndex] for what the rule
/// cannot see, and why a name two declarations both claim is dropped from the
/// graph rather than fused.
///
/// Every class on the loop is reported, because every one of them is a place
/// the loop could be broken. Only one loop is reported at a time, which is
/// what the build does with the same graph.
class DependencyCycle extends AnalysisRule {
  /// Creates the rule.
  DependencyCycle()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_dependency_cycle',
    "'{0}' depends on itself through {1}.",
    correctionMessage:
        'Break the loop: depend on a narrower interface one side can provide, '
        'or move what both need into a third registration.',
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
  static const _modules = CobaltModuleParser();

  final AnalysisRule rule;
  final RuleContext context;
  final CobaltRegistrationIndexCache _cache;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null) return;

    final List<CobaltInjectableClass> declarations;
    try {
      if (_parser.declares(element)) {
        declarations = _parser.parseClass(element);
      } else if (_modules.declares(element)) {
        declarations = _modules.parseClass(element);
      } else {
        return;
      }
    } on CobaltParseError {
      // A malformed declaration is somebody else's rule to report, and what it
      // registers cannot be trusted.
      return;
    }

    final cycle = _index()?.cycle;
    if (cycle == null) return;

    for (final declaration in declarations) {
      final registered = declaration.exposedType.name;
      if (!cycle.contains(registered)) continue;
      rule.reportAtNode(
        node.namePart,
        arguments: [declaration.label, _describe(cycle, registered)],
      );
      return;
    }
  }

  /// The loop written out from [start], so each report reads as a path leaving
  /// and returning to the class it is attached to.
  static String _describe(List<String> cycle, String start) {
    // The last entry repeats the first; drop it before rotating, then close
    // the path again at the end.
    final ring = cycle.sublist(0, cycle.length - 1);
    final at = ring.indexOf(start);
    final rotated = at <= 0
        ? ring
        : [...ring.sublist(at), ...ring.sublist(0, at)];
    return [...rotated, start].join(' -> ');
  }

  CobaltRegistrationIndex? _index() {
    final root = context.package?.root;
    final session = context.libraryElement?.session;
    if (root == null || session == null) return null;
    return _cache.of(root, session);
  }
}
