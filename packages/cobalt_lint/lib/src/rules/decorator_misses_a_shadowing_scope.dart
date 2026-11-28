import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/registration_index.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

class DecoratorMissesAShadowingScope extends AnalysisRule {
  DecoratorMissesAShadowingScope()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  static const code = LintCode(
    'cobalt_decorator_misses_a_shadowing_scope',
    "'{0}' decorates {1} in the root, but the child scope {2} registers {1} "
        "too and hands it out without '{0}'.",
    correctionMessage:
        '@CobaltDecorates has no scope:, so a decorator of a root registration '
        'never reaches a child scope that registers the same key. {3}',
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

  final _decorators = const CobaltDecoratorParser();

  final AnalysisRule rule;
  final RuleContext context;
  final CobaltRegistrationIndexCache _cache;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null || !_decorators.declares(element)) return;
    final decorator = _decoratorOf(element);
    if (decorator == null) return;
    final scopes = _shadowingScopes(decorator, element);
    if (scopes.isEmpty) return;

    rule.reportAtNode(
      node.namePart,
      arguments: [
        decorator.type.name,
        _describe(decorator),
        (scopes.toList()..sort()).join(', '),
        _remedy(decorator),
      ],
    );
  }

  Set<String> _shadowingScopes(
    CobaltDecoratorClass decorator,
    ClassElement element,
  ) {
    final target = decorator.target;
    if (decorator.environments.isNotEmpty || target.typeArguments.isNotEmpty) {
      return const {};
    }
    final index = _index();
    if (index == null) return const {};
    if (_isForeign(target, element) && index.classNames.contains(target.name)) {
      return const {};
    }
    return index.scopesShadowingRoot(
      target.name,
      name: decorator.name,
      allNames: decorator.allNames,
    );
  }

  CobaltDecoratorClass? _decoratorOf(ClassElement element) {
    try {
      return _decorators.parseClass(element);
    } on CobaltParseError {
      return null;
    }
  }

  bool _isForeign(CobaltTypeRef target, ClassElement decorator) =>
      _packageOf(target.import) != _packageOf(decorator.library.uri.toString());

  String? _packageOf(String? uri) {
    if (uri == null || !uri.startsWith('package:')) return uri;
    return uri.substring('package:'.length).split('/').first;
  }

  String _remedy(
    CobaltDecoratorClass decorator,
  ) => switch (decorator.allNames) {
    true =>
      'Drop the registration from the child scope: the decorator wraps '
          'every name, so another one does not help.',
    false =>
      'Drop the registration from the child scope, or give it another name.',
  };

  String _describe(CobaltDecoratorClass decorator) => switch (decorator.name) {
    final name? => "${decorator.target.name} named '$name'",
    null => decorator.target.name,
  };

  CobaltRegistrationIndex? _index() {
    final root = context.package?.root;
    final session = context.libraryElement?.session;
    if (root == null || session == null) return null;
    return _cache.of(root, session);
  }
}
