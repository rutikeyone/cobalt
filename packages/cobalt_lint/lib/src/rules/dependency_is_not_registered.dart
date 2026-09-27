import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/registration_index.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Reports a dependency of an injectable class that nothing in the package
/// registers — and, for an `@CobaltDecorates` class, a target or a dependency
/// nothing registers.
///
/// The build already rejects such a graph. This is the same answer earlier, in
/// the editor, from a coarser view — see [CobaltRegistrationIndex] for what the
/// rule cannot see and why it errs towards silence.
class DependencyIsNotRegistered extends AnalysisRule {
  /// Creates the rule.
  DependencyIsNotRegistered()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_dependency_is_not_registered',
    "'{0}' needs '{1}', which nothing in this package registers.",
    correctionMessage:
        'Annotate the class that provides it with @CobaltInject, or name it in '
        '@CobaltScopeRoot(provides: [...]) when something outside the generated '
        'container registers it.',
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
  static const _decorators = CobaltDecoratorParser();

  final AnalysisRule rule;
  final RuleContext context;
  final CobaltRegistrationIndexCache _cache;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null) return;

    if (_decorators.declares(element)) {
      _checkDecorator(node, element);
      return;
    }

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
      // A malformed declaration is somebody else's rule to report, and its
      // dependency list cannot be trusted.
      return;
    }

    final index = _index();
    if (index == null) return;

    for (final declaration in declarations) {
      final missing = _firstMissing(declaration, index);
      if (missing == null) continue;
      rule.reportAtNode(node.namePart, arguments: [declaration.label, missing]);
      return;
    }
  }

  /// A decorator needs its target registered as well as its own
  /// dependencies: wrapping something nothing makes wraps nothing.
  void _checkDecorator(ClassDeclaration node, ClassElement element) {
    final CobaltDecoratorClass decorator;
    try {
      decorator = _decorators.parseClass(element);
    } on CobaltParseError {
      return;
    }

    final index = _index();
    if (index == null) return;

    final wanted = [
      decorator.target,
      for (final parameter in decorator.dependencies) parameter.type,
    ];
    for (final type in wanted) {
      if (type.isNullable || index.contains(type.name)) continue;
      rule.reportAtNode(
        node.namePart,
        arguments: [decorator.type.name, type.name],
      );
      return;
    }
  }

  String? _firstMissing(
    CobaltInjectableClass declaration,
    CobaltRegistrationIndex index,
  ) {
    // A list, not a set. `CobaltTypeRef` compares by signature, which ignores
    // nullability, so a class taking both `Foo` and `Foo?` would collapse into
    // one entry and whichever came first would decide whether the required one
    // is checked at all.
    final wanted = <CobaltTypeRef>[
      // An `@CobaltParam` is not a dependency: the call site supplies it, and
      // nothing registers an `int`. Without this the rule reports every
      // parameterized class as broken.
      for (final parameter in declaration.constructorParameters)
        if (!parameter.isParam) parameter.type,
      for (final property in declaration.properties) property.type,
      ...declaration.dependsOn,
    ];

    for (final type in wanted) {
      if (type.isNullable) continue;
      if (!index.contains(type.name)) return type.name;
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
