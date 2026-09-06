import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/teardown_shape.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// Reports a registration that holds something closeable and offers no way to
/// close it.
///
/// The sibling of `cobalt_registration_is_never_released`, for the case that
/// one cannot see. That rule asks what a class *is* — a class with a teardown
/// method the scope was never told about. This one asks what a class *holds*:
/// a `StreamSubscription` in a field, and no method anywhere that would cancel
/// it. The scope retains only what says how to close, so such a class is never
/// retained, never released, and the subscription outlives the scope that
/// built it.
///
/// Measured before this rule existed: five session scopes, a subscription
/// each, one `dispose()` of the root — five live listeners afterwards. Nothing
/// caught it. The runtime cannot: it is handed an object that offers nothing
/// to call.
///
/// Structural rather than a list of types. A field counts when its own type
/// offers a teardown-shaped method, so `StreamSubscription.cancel`,
/// `StreamController.close` and `Timer.cancel` are found for the same reason
/// as anything else built the same way — including types this package has
/// never heard of.
class ResourceIsNeverClosed extends AnalysisRule {
  /// Creates the rule.
  ResourceIsNeverClosed()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_resource_is_never_closed',
    "'{0}' is registered and holds '{1}', which has to be closed — but '{0}' "
        'offers nothing that would close it.',
    correctionMessage:
        'Give it a dispose() and implement Disposable, or AsyncDisposable when '
        'closing returns a Future. A scope keeps only what says how to close, '
        'so this one is released the moment nothing else points at it — and '
        'the resource keeps running.',
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

  /// What the runtime recognises, matched by name rather than by library —
  /// the same trade the sibling rule makes, and for the same reason.
  static const _recognised = {'Disposable', 'AsyncDisposable'};

  final AnalysisRule rule;

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

    // Nothing the scope does not retain can be released by it, so there is
    // nothing to report — the caller closes what it built.
    if (declaration.lifetime == CobaltLifetime.transient) return;
    if (declaration.constructorParameters.any((it) => it.isParam)) return;
    if (declaration.dispose != null) return;
    if (_saysHow(element)) return;

    // A class that offers a teardown of its own belongs to the sibling rule:
    // it is not missing a way to close, it is missing the declaration that
    // makes the scope call one. Two diagnostics about one class would send
    // the reader to fix it twice.
    if (teardownMethodOf(element) != null) return;

    final held = _closeableFieldOf(element);
    if (held == null) return;

    rule.reportAtNode(
      node.namePart,
      arguments: [node.namePart.typeName.lexeme, held],
    );
  }

  bool _saysHow(ClassElement element) => element.allSupertypes.any(
    (supertype) => _recognised.contains(supertype.element.name),
  );

  /// The type of the first field that has to be closed, or null when none of
  /// them do.
  String? _closeableFieldOf(ClassElement element) {
    for (final field in element.fields) {
      if (field.isStatic) continue;
      final type = field.type;
      if (type is! InterfaceType) continue;
      final fieldElement = type.element;
      if (fieldElement is ClassElement && _isScopeOwned(fieldElement)) {
        continue;
      }
      if (teardownMethodOf(fieldElement) == null) continue;
      return fieldElement.name ?? field.displayName;
    }
    return null;
  }

  /// Whether the scope already owns [fieldElement] through a registration of
  /// its own, and disposes it independently in its own turn of the teardown
  /// order.
  ///
  /// A field holding a reference to another retained registration is the
  /// ordinary shape of a dependency graph — every constructor parameter that
  /// is itself `@CobaltInject`/`@CobaltInit` looks exactly like this. Without
  /// this check the rule fired on that shape as often as on a real leak: two
  /// singletons in this repository's own example, `NoteRepository` and
  /// `SearchIndex`, both hold a `NoteDatabase` the scope already disposes on
  /// its own, and neither is this class's to close.
  ///
  /// A *transient* or *parameterized* registration is not retained, so
  /// nothing else is going to close it — the holder still has to say how, and
  /// this returns false for those on purpose.
  bool _isScopeOwned(ClassElement fieldElement) {
    if (!_parser.declares(fieldElement)) return false;
    try {
      final declaration = _parser.parseClass(fieldElement);
      return declaration.lifetime != CobaltLifetime.transient &&
          !declaration.constructorParameters.any((it) => it.isParam);
    } on CobaltParseError {
      return false;
    }
  }
}
