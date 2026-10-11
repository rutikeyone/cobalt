import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Reports `BlocProvider(create: ...)` handing out a bloc read from a Cobalt
/// scope.
///
/// `BlocProvider(create:)` closes what it created when it unmounts, and the
/// scope that built the bloc still holds it: the next screen to read it gets a
/// closed bloc, and the scope closes it a second time when it ends.
/// `BlocProvider.value` hands it to the tree without taking it over.
///
/// Read from syntax alone, so it needs neither `flutter_bloc` nor a resolved
/// type: a `BlocProvider` call whose `create` reads `context.cobalt`,
/// `context.cobaltWithParam`, `scope.get` or `scope.getWithParam`.
class BlocProviderClosesAScopedBloc extends AnalysisRule {
  /// Creates the rule.
  BlocProviderClosesAScopedBloc()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_bloc_provider_closes_a_scoped_bloc',
    'BlocProvider(create:) closes a bloc that a Cobalt scope still holds.',
    correctionMessage: 'Use BlocProvider.value(value: ..., child: ...).',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addInstanceCreationExpression(this, visitor)
      ..addMethodInvocation(this, visitor);
  }
}

/// The `create:` argument of a `BlocProvider(...)` call, or null when [node]
/// is not one.
NamedExpression? blocProviderCreate(AstNode node) {
  final ArgumentList arguments;
  switch (node) {
    case InstanceCreationExpression(
          constructorName: ConstructorName(name: null, :final type),
        )
        when type.name.lexeme == 'BlocProvider':
      arguments = node.argumentList;
    case MethodInvocation(target: null, :final methodName)
        when methodName.name == 'BlocProvider':
      arguments = node.argumentList;
    default:
      return null;
  }
  for (final argument in arguments.arguments) {
    if (argument is NamedExpression && argument.name.label.name == 'create') {
      return argument;
    }
  }
  return null;
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) =>
      _check(node);

  @override
  void visitMethodInvocation(MethodInvocation node) => _check(node);

  void _check(AstNode node) {
    final create = blocProviderCreate(node);
    if (create == null) return;
    final finder = _ReadsFromScope();
    create.expression.accept(finder);
    if (finder.found) rule.reportAtNode(create);
  }
}

class _ReadsFromScope extends RecursiveAstVisitor<void> {
  static const _reads = {'cobalt', 'cobaltWithParam', 'get', 'getWithParam'};

  var found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (_reads.contains(name) &&
        (name.startsWith('cobalt') || _isScope(node.realTarget))) {
      found = true;
      return;
    }
    super.visitMethodInvocation(node);
  }

  static bool _isScope(Expression? target) {
    if (target == null) return false;
    final type = target.staticType?.element?.name;
    if (type == 'CobaltScope' || type == 'CobaltResolver') return true;
    return switch (target) {
      SimpleIdentifier(:final name) => name == 'scope',
      PrefixedIdentifier(:final identifier) => identifier.name == 'cobaltScope',
      PropertyAccess(:final propertyName) => propertyName.name == 'cobaltScope',
      _ => false,
    };
  }
}
