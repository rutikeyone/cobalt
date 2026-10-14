import 'package:cobalt_lint/src/registration_index.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

class ReadDoesNotMatchRegistration extends MultiAnalysisRule {
  ReadDoesNotMatchRegistration()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  static const code = LintCode(
    'cobalt_read_does_not_match_registration',
    "'{0}' takes a value from the call site, so {1} always throws.",
    correctionMessage: 'Resolve it with {2}<{0}, ...>(...) and pass the value.',
  );

  static const asyncParam = LintCode(
    'cobalt_read_does_not_match_registration',
    "'{0}' is built asynchronously from its value, so {1} always throws.",
    correctionMessage:
        'Resolve it with getAsyncWithParam<{0}, ...>(...), '
        'context.cobaltAsyncWithParam in a widget, and await it.',
    uniqueName: 'LintCode.cobalt_read_does_not_match_registration_async_param',
  );

  static const notParameterized = LintCode(
    'cobalt_read_does_not_match_registration',
    "'{0}' takes no value from the call site, so {1} always throws.",
    correctionMessage: 'Resolve it with {2}<{0}>().',
    uniqueName:
        'LintCode.cobalt_read_does_not_match_registration_not_parameterized',
  );

  final _cache = CobaltRegistrationIndexCache();

  @override
  List<DiagnosticCode> get diagnosticCodes => const [
    code,
    asyncParam,
    notParameterized,
  ];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) => registry.addMethodInvocation(this, _Visitor(this, context, _cache));
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context, this._cache);

  static const _owners = {
    ('cobalt', 'CobaltResolver'),
    ('cobalt', 'CobaltScope'),
    ('cobalt_flutter', 'CobaltBuildContext'),
  };

  static const _withoutValue = {
    'get': false,
    'getOrNull': false,
    'getAll': false,
    'getAsync': true,
    'cobalt': false,
    'cobaltAll': false,
    'cobaltAsync': true,
  };

  static const _withValue = {
    'getWithParam': false,
    'getAsyncWithParam': true,
    'cobaltWithParam': false,
    'cobaltAsyncWithParam': true,
  };

  final MultiAnalysisRule rule;
  final RuleContext context;
  final CobaltRegistrationIndexCache _cache;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName;
    final owner = method.element?.enclosingElement;
    final ownerName = owner?.name;
    final uri = owner?.library?.uri;
    if (ownerName == null || uri == null || uri.scheme != 'package') return;
    if (!_owners.contains((uri.pathSegments.first, ownerName))) return;
    final read = method.name;
    if (!_withoutValue.containsKey(read) && !_withValue.containsKey(read)) {
      return;
    }

    final types = node.typeArgumentTypes;
    if (types == null || types.isEmpty) return;
    final type = types.first;
    if (type is! InterfaceType) return;
    final name = type.element.name;
    if (name == null) return;

    final index = _index();
    if (index == null) return;
    final widget = uri.pathSegments.first == 'cobalt_flutter';
    final call = '$read<$name>()';

    if (_withoutValue[read] case final isAsync?) {
      final takesValue =
          index.withParams.contains(name) ||
          index.asyncWithParams.contains(name);
      if (!takesValue) return;
      final async = isAsync || index.asyncWithParams.contains(name);
      final fix = widget
          ? (async ? 'context.cobaltAsyncWithParam' : 'context.cobaltWithParam')
          : (async ? 'getAsyncWithParam' : 'getWithParam');
      rule.reportAtNode(
        method,
        diagnosticCode: ReadDoesNotMatchRegistration.code,
        arguments: [name, call, fix],
      );
      return;
    }

    final isAsync = _withValue[read]!;
    if (!isAsync && index.asyncWithParams.contains(name)) {
      rule.reportAtNode(
        method,
        diagnosticCode: ReadDoesNotMatchRegistration.asyncParam,
        arguments: [name, call],
      );
      return;
    }
    if (index.withoutParams.contains(name)) {
      final fix = widget
          ? (isAsync ? 'context.cobaltAsync' : 'context.cobalt')
          : (isAsync ? 'getAsync' : 'get');
      rule.reportAtNode(
        method,
        diagnosticCode: ReadDoesNotMatchRegistration.notParameterized,
        arguments: [name, call, fix],
      );
    }
  }

  CobaltRegistrationIndex? _index() {
    final root = context.package?.root;
    final session = context.libraryElement?.session;
    if (root == null || session == null) return null;
    return _cache.of(root, session);
  }
}
