import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Reports `hookAll` on a scope that has already built something.
///
/// A hook added after a build would never see what was built, so the scope
/// refuses it with `CobaltHookError` — at runtime. The usual way to get there
/// is visible in the source: an eager registration, whose instance is built
/// the moment it is registered, or a `get` a few lines up, and then the hook.
///
/// Only what reads plainly: an earlier section of the same cascade, or an
/// earlier statement of the same block on the same local variable or
/// parameter. A build that happens elsewhere — in a scope below, in another
/// function — is the runtime check's to catch.
class HookAddedTooLate extends AnalysisRule {
  /// Creates the rule.
  HookAddedTooLate()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_hook_added_too_late',
    "hookAll comes after '{0}' on the same scope, which has built something "
        'by then, so the scope throws CobaltHookError.',
    correctionMessage:
        'Add hooks where the scope is composed, before any eager '
        'registration and before anything is resolved.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) => registry.addMethodInvocation(this, _Visitor(this));
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  /// What builds an instance on the scope it is called on.
  static const _builds = {
    'registerEagerSingleton',
    'get',
    'getOrNull',
    'getAll',
    'getWithParam',
    'getAsync',
    'getAllAsync',
    'getAsyncWithParam',
    'init',
    'warmUp',
  };

  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'hookAll' || !_onScope(node)) return;

    final parent = node.parent;
    if (parent is CascadeExpression) {
      for (final section in parent.cascadeSections) {
        if (identical(section, node)) break;
        if (_builder(section) case final build?) {
          rule.reportAtNode(node.methodName, arguments: [build]);
          return;
        }
      }
    }

    final receiver = _elementOf(node.realTarget);
    if (receiver == null) return;
    final statement = node.thisOrAncestorOfType<Statement>();
    final block = statement?.parent;
    if (statement == null || block is! Block) return;
    for (final earlier in block.statements) {
      if (identical(earlier, statement)) break;
      for (final call in _callsIn(earlier)) {
        if (_elementOf(call.realTarget) != receiver) continue;
        if (_builder(call) case final build?) {
          rule.reportAtNode(node.methodName, arguments: [build]);
          return;
        }
      }
    }
  }

  /// The calls a statement makes directly: `x.m()`, `await x.m()`, and each
  /// section of `x..a()..b()` — not what a closure inside it might do later.
  static Iterable<MethodInvocation> _callsIn(Statement statement) sync* {
    final expression = switch (statement) {
      ExpressionStatement(:final expression) => expression,
      _ => null,
    };
    final unwrapped = expression is AwaitExpression
        ? expression.expression
        : expression;
    switch (unwrapped) {
      case MethodInvocation():
        yield unwrapped;
      case CascadeExpression(:final cascadeSections):
        yield* cascadeSections.whereType<MethodInvocation>();
    }
  }

  /// The name of the call when [expression] builds on a scope.
  static String? _builder(Expression expression) {
    if (expression is! MethodInvocation) return null;
    final name = expression.methodName.name;
    if (!_builds.contains(name) || !_onScope(expression)) return null;
    return name;
  }

  /// Whether [node] calls a method of Cobalt's scope or resolver.
  static bool _onScope(MethodInvocation node) {
    final owner = node.methodName.element?.enclosingElement;
    final uri = owner?.library?.uri;
    return uri != null &&
        uri.scheme == 'package' &&
        uri.pathSegments.first == 'cobalt' &&
        (owner?.name == 'CobaltScope' || owner?.name == 'CobaltResolver');
  }

  /// The local variable or parameter [expression] names, if it is one.
  static Element? _elementOf(Expression? expression) =>
      expression is SimpleIdentifier ? expression.element : null;
}
