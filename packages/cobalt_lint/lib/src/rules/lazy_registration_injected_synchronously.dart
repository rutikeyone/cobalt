import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/registration_index.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Reports a class that injects a lazy async registration where nothing can
/// wait for it.
///
/// A lazy async registration is built by the first `getAsync`, so a
/// synchronous or eager async class taking one in its constructor, and any
/// class holding one in an `@injected` field, would find it unbuilt. The build
/// already refuses such a graph; this is the same answer in the editor, read
/// from the package-wide [CobaltRegistrationIndex].
class LazyRegistrationInjectedSynchronously extends AnalysisRule {
  /// Creates the rule.
  LazyRegistrationInjectedSynchronously()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_lazy_registration_injected_synchronously',
    "'{0}' injects '{1}', which is registered lazily and is not built until "
        'the first getAsync.',
    correctionMessage:
        "Make '{0}' lazy too with @CobaltInit(lazy: true), so its factory "
        "awaits '{1}', or resolve '{1}' with getAsync where it is needed.",
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
        declarations = [_parser.parseClass(element)];
      } else if (_modules.declares(element)) {
        declarations = _modules.parseClass(element);
      } else {
        return;
      }
    } on CobaltParseError {
      return;
    }

    final index = _index();
    if (index == null || index.lazy.isEmpty) return;

    for (final declaration in declarations) {
      final injected = _firstLazy(declaration, index);
      if (injected == null) continue;
      rule.reportAtNode(
        node.namePart,
        arguments: [declaration.label, injected],
      );
      return;
    }
  }

  /// The first lazy type [declaration] takes where it cannot await it.
  ///
  /// A lazy class may take lazy dependencies in its constructor — its factory
  /// awaits them — but no class can hold one in an `@injected` field, which is
  /// filled synchronously after construction.
  String? _firstLazy(
    CobaltInjectableClass declaration,
    CobaltRegistrationIndex index,
  ) {
    if (!declaration.isLazyAsync) {
      for (final parameter in declaration.constructorParameters) {
        if (parameter.isParam) continue;
        if (index.lazy.contains(parameter.type.name)) {
          return parameter.type.name;
        }
      }
    }
    for (final property in declaration.properties) {
      if (index.lazy.contains(property.type.name)) return property.type.name;
    }
    return null;
  }

  CobaltRegistrationIndex? _index() {
    final root = context.package?.root;
    final session = context.libraryElement?.session;
    if (root == null || session == null) return null;
    return _cache.of(root, session);
  }
}
