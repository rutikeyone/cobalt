import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/emitters/cobalt_references.dart';
import 'package:code_builder/code_builder.dart';

class BootstrapEmitter {
  const BootstrapEmitter();

  /// Emits `cobaltBootstrapSteps` as a getter rather than a stored list, so every
  /// startup gets fresh step instances. A top-level `final` would build them
  /// once per process, which quietly shares state between a retried startup
  /// and between tests, and leaves them alive after the scope that adopted
  /// them is gone.
  ///
  /// When any step names an environment it becomes a function of the chosen
  /// environment instead, because the list is then no longer the same for
  /// every build.

  Method emit(
    List<CobaltBootstrapStepClass> steps, {
    required bool usesEnvironments,
  }) {
    final ordered = [...steps]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.type.name.compareTo(b.type.name);
      });

    return Method(
      (m) => m
        ..name = 'cobaltBootstrapSteps'
        ..type = usesEnvironments ? null : MethodType.getter
        ..requiredParameters.addAll([
          if (usesEnvironments)
            Parameter(
              (p) => p
                ..name = 'environment'
                ..type = cobaltRef('CobaltEnvironment'),
            ),
        ])
        ..returns = TypeReference(
          (b) => b
            ..symbol = 'List'
            ..url = 'dart:core'
            ..types.add(cobaltRef('CobaltBootstrapStep')),
        )
        ..lambda = true
        ..body = Block.of([
          const Code('['),
          for (final step in ordered) ...[
            if (step.environments.isNotEmpty) ...[
              const Code('if ('),
              environmentGuard(step.environments).code,
              const Code(') '),
            ],
            typeReferenceOf(step.type).newInstance(const []).code,
            const Code(','),
          ],
          const Code(']'),
        ]),
    );
  }

  Method emitDeprecated({required bool usesEnvironments}) => Method(
    (m) => m
      ..name = r'$cobaltBootstrap'
      ..annotations.add(deprecatedFor('cobaltBootstrapSteps'))
      ..type = usesEnvironments ? null : MethodType.getter
      ..requiredParameters.addAll([
        if (usesEnvironments)
          Parameter(
            (p) => p
              ..name = 'environment'
              ..type = cobaltRef('CobaltEnvironment'),
          ),
      ])
      ..returns = TypeReference(
        (b) => b
          ..symbol = 'List'
          ..url = 'dart:core'
          ..types.add(cobaltRef('CobaltBootstrapStep')),
      )
      ..lambda = true
      ..body = usesEnvironments
          ? refer('cobaltBootstrapSteps').call([refer('environment')]).code
          : refer('cobaltBootstrapSteps').code,
  );
}
