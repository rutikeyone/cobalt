import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/file_system.dart';

/// Reports a registered class that `lib/cobalt.g.dart` does not mention yet.
///
/// The class was annotated after the last build, so the app starts without
/// it and the first resolve throws `CobaltNotRegisteredError`. The editor can
/// say so as soon as the annotation is written.
///
/// Silent while there is no `lib/cobalt.g.dart` at all: before the first build
/// the import of it is already an error, and that one says what to do.
class RegistrationIsNotGenerated extends AnalysisRule {
  /// Creates the rule.
  RegistrationIsNotGenerated()
    : super(name: code.lowerCaseName, description: code.problemMessage);

  /// The diagnostic this rule reports.
  static const code = LintCode(
    'cobalt_registration_is_not_generated',
    "'{0}' is annotated, but lib/cobalt.g.dart does not register it yet.",
    correctionMessage: "Run 'dart run build_runner build'.",
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) => registry.addClassDeclaration(this, _Visitor(this, context));
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  static const _parser = CobaltInjectableParser();
  static const _modules = CobaltModuleParser();

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final element = node.declaredFragment?.element;
    if (element == null) return;
    if (!_parser.declares(element) && !_modules.declares(element)) return;

    final lib = context.package?.root.getChild('lib');
    if (lib is! Folder) return;
    final path = element.library.firstFragment.source.fullName;
    if (!lib.contains(path)) return;
    final generated = lib.getChild('cobalt.g.dart');
    if (generated is! File || !generated.exists) return;

    final name = node.namePart.typeName.lexeme;
    final mentioned = RegExp(
      '_i\\d+\\.${RegExp.escape(name)}\\b',
    ).hasMatch(generated.readAsStringSync());
    if (!mentioned) rule.reportAtNode(node.namePart, arguments: [name]);
  }
}
