import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/teardown_shape.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

/// Reports a registration the scope will hold and never close.
///
/// A scope releases what implements `Disposable` or `AsyncDisposable`, plus
/// whatever a registration named a `dispose:` function for. Dart has no
/// structural typing, so a matching method is not enough — and almost every
/// object a Flutter application registers has one without the declaration:
/// `ChangeNotifier.dispose` matches the interface exactly and is still
/// invisible, `Bloc.close` is not even the right name. Forgetting is quiet:
/// the object is built, used, and never closed.
///
/// Only teardown-shaped methods count — no required parameters, returning
/// `void` or a `Future` — so a `close()` that means something else is left
/// alone.
class RegistrationIsNeverReleased extends AnalysisRule {
  /// Creates the rule.
  RegistrationIsNeverReleased()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_registration_is_never_released',
    "'{0}' is registered and declares '{1}()', but nothing tells the scope to "
        'call it.',
    correctionMessage:
        'Implement Disposable, or AsyncDisposable when closing returns a '
        'Future — a matching method alone is invisible to the scope. For a '
        'base class you cannot change, name a function with '
        '@CobaltInject(dispose: ...).',
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

  /// What the runtime recognises.
  ///
  /// Matched by name and not by library on purpose: a `Disposable` of somebody
  /// else's makes this rule silent, and silence is the direction a rule that
  /// cannot see the whole graph should fail in.
  static const _recognised = {'Disposable', 'AsyncDisposable'};

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null || !_parser.declares(element)) return;

    final CobaltInjectableClass declaration;
    try {
      declaration = _parser.parseClass(element).first;
    } on CobaltParseError {
      // A declaration the generator will refuse anyway. Another rule names it.
      return;
    }

    // The scope retains neither a transient nor a parameterized registration,
    // so there is nothing for it to release and nothing to report.
    if (declaration.lifetime == CobaltLifetime.transient) return;
    if (declaration.constructorParameters.any((it) => it.isParam)) return;
    if (declaration.dispose != null) return;
    if (_saysHow(element)) return;

    final closing = teardownMethodOf(element);
    if (closing == null) return;

    rule.reportAtNode(
      node.namePart,
      arguments: [node.namePart.typeName.lexeme, closing],
    );
  }

  bool _saysHow(ClassElement element) => element.allSupertypes.any(
    (supertype) => _recognised.contains(supertype.element.name),
  );
}
