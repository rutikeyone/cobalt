import 'dart:convert';

import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/emitters/container_source_emitter.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';

/// Aggregates every per-library IR file into one container.
///
/// Runs once per package against the synthetic `$lib$` input, because the
/// container is a whole-program artifact that no single library owns.
class CobaltContainerBuilder implements Builder {
  const CobaltContainerBuilder();

  static const _emitter = ContainerSourceEmitter();

  @override
  Map<String, List<String>> get buildExtensions => const {
    r'$lib$': ['cobalt.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final injectables = <CobaltInjectableClass>[];
    final bootstrapSteps = <CobaltBootstrapStepClass>[];
    final scopeRoots = <CobaltScopeRootClass>[];
    final decorators = <CobaltDecoratorClass>[];

    await for (final id in buildStep.findAssets(Glob('lib/**.cobalt.json'))) {
      final decoded = CobaltLibraryDeclarations.fromJson(
        jsonDecode(await buildStep.readAsString(id)) as Map<String, dynamic>,
      );
      injectables.addAll(decoded.injectables);
      bootstrapSteps.addAll(decoded.bootstrapSteps);
      scopeRoots.addAll(decoded.scopeRoots);
      decorators.addAll(decoded.decorators);
    }

    final declarations = CobaltLibraryDeclarations(
      injectables: injectables,
      bootstrapSteps: bootstrapSteps,
      scopeRoots: scopeRoots,
      decorators: decorators,
    );
    if (declarations.isEmpty) return;

    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, 'lib/cobalt.g.dart'),
      _emitter.emit(declarations),
    );
  }
}
