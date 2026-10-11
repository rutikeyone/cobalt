import 'package:cobalt_lint/src/rules/bloc_provider_closes_a_scoped_bloc.dart';
import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// Rewrites `BlocProvider(create: (_) => <read>, ...)` to
/// `BlocProvider.value(value: <read>, ...)`.
///
/// Offered only where the rewrite keeps the meaning: `create` returns one
/// expression, its parameter is `_` or `context` so the expression reads the
/// same outside it, and there is no `lazy:`, which `BlocProvider.value` does
/// not take.
class UseBlocProviderValue extends ResolvedCorrectionProducer {
  /// Creates the producer for the diagnostic in [context].
  UseBlocProviderValue({required super.context});

  static const _kind = FixKind(
    'cobalt.fix.useBlocProviderValue',
    DartFixKindPriority.standard,
    'Use BlocProvider.value',
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final call = node.thisOrAncestorMatching(
      (candidate) => blocProviderCreate(candidate) != null,
    );
    if (call == null) return;
    final create = blocProviderCreate(call)!;

    final function = create.value;
    if (function is! FunctionExpression) return;
    final body = function.body;
    if (body is! ExpressionFunctionBody) return;
    final parameters =
        function.parameters?.parameters ?? const <FormalParameter>[];
    if (parameters.length != 1) return;
    final parameter = parameters.single.name?.lexeme;
    if (parameter != '_' && parameter != 'context') return;

    final ArgumentList arguments;
    final int nameEnd;
    switch (call) {
      case InstanceCreationExpression():
        arguments = call.argumentList;
        nameEnd = call.constructorName.end;
      case MethodInvocation():
        arguments = call.argumentList;
        nameEnd = call.methodName.end;
      default:
        return;
    }
    final hasLazy = arguments.arguments.any(
      (AstNode argument) => labelOf(argument) == 'lazy',
    );
    if (hasLazy) return;

    final value = body.expression.toSource();
    await builder.addDartFileEdit(file, (builder) {
      builder
        ..addSimpleInsertion(nameEnd, '.value')
        ..addSimpleReplacement(
          SourceRange(create.argument.offset, create.argument.length),
          'value: $value',
        );
    });
  }
}
