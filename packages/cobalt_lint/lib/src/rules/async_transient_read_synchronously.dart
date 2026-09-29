import 'package:cobalt_lint/src/registration_index.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// Reports a synchronous read of an async transient.
///
/// An async transient is built anew by every `getAsync`, and there is never a
/// built instance for `get`, `getOrNull` or `getAll` to hand back — each of
/// them throws `CobaltAsyncTransientError`, every time. This moves that
/// failure into the editor.
///
/// Async transients only, by design. A lazy async singleton is legitimately
/// read with `get` once the first `getAsync` or a `warmUp` has built it, so
/// reporting those would flag correct code.
///
/// The registrations come from the package-wide [CobaltRegistrationIndex], so
/// only what the package declares with annotations is known. A registration
/// written by hand with `registerAsyncFactory` is not, and is not reported.
class AsyncTransientReadSynchronously extends AnalysisRule {
  /// Creates the rule.
  AsyncTransientReadSynchronously()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_async_transient_read_synchronously',
    "'{0}' is an async transient, built anew by every getAsync, so {1} always "
        'throws.',
    correctionMessage:
        "Resolve it with getAsync<{0}>() — getAllAsync for a list, "
        'context.cobaltAsync in a widget — and await it.',
  );

  final _cache = CobaltRegistrationIndexCache();

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) => registry.addMethodInvocation(this, _Visitor(this, context, _cache));
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context, this._cache);

  /// The synchronous reads, by the declaration that owns them.
  static const _reads = {
    ('cobalt', 'CobaltResolver'): {'get', 'getOrNull', 'getAll'},
    ('cobalt', 'CobaltScope'): {'get', 'getOrNull', 'getAll'},
    ('cobalt_flutter', 'CobaltBuildContext'): {'cobalt', 'cobaltAll'},
  };

  final AnalysisRule rule;
  final RuleContext context;
  final CobaltRegistrationIndexCache _cache;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName;
    final owner = method.element?.enclosingElement;
    final ownerName = owner?.name;
    final uri = owner?.library?.uri;
    if (ownerName == null || uri == null || uri.scheme != 'package') return;
    final reads = _reads[(uri.pathSegments.first, ownerName)];
    if (reads == null || !reads.contains(method.name)) return;

    // Written or inferred alike: `get<Report>()` and `final Report r = get()`.
    final types = node.typeArgumentTypes;
    if (types == null || types.isEmpty) return;
    final type = types.first;
    if (type is! InterfaceType) return;
    final name = type.element.name;
    if (name == null) return;

    final index = _index();
    if (index == null || !index.asyncTransients.contains(name)) return;

    rule.reportAtNode(method, arguments: [name, '${method.name}<$name>()']);
  }

  CobaltRegistrationIndex? _index() {
    final root = context.package?.root;
    final session = context.libraryElement?.session;
    if (root == null || session == null) return null;
    return _cache.of(root, session);
  }
}
