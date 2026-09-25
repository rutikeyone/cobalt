import 'package:cobalt_analyzer/src/model/library_declarations.dart';
import 'package:cobalt_analyzer/src/parser/bootstrap_parser.dart';
import 'package:cobalt_analyzer/src/parser/decorator_parser.dart';
import 'package:cobalt_analyzer/src/parser/injectable_parser.dart';
import 'package:cobalt_analyzer/src/parser/module_parser.dart';
import 'package:cobalt_analyzer/src/parser/scope_root_parser.dart';
import 'package:analyzer/dart/element/element.dart';

/// Reads every Cobalt declaration out of one library.
class CobaltParser {
  const CobaltParser();

  static const _injectables = CobaltInjectableParser();
  static const _bootstrap = CobaltBootstrapParser();
  static const _scopeRoot = CobaltScopeRootParser();
  static const _modules = CobaltModuleParser();
  static const _decorators = CobaltDecoratorParser();

  /// Collects the injectables, bootstrap steps, scope roots and decorators
  /// declared in [library]. Throws `CobaltParseError` for a declaration Cobalt cannot use.
  CobaltLibraryDeclarations parseLibrary(LibraryElement library) {
    final classes = library.classes;

    return CobaltLibraryDeclarations(
      injectables: [
        for (final clazz in classes)
          if (_injectables.declares(clazz)) _injectables.parseClass(clazz),
        // A module is the one declaration that yields many registrations, so
        // this spreads where the others append.
        for (final clazz in classes)
          if (_modules.declares(clazz)) ..._modules.parseClass(clazz),
      ],
      bootstrapSteps: [
        for (final clazz in classes)
          if (_bootstrap.declares(clazz)) _bootstrap.parseClass(clazz),
      ],
      scopeRoots: [
        for (final clazz in classes)
          if (_scopeRoot.declares(clazz)) _scopeRoot.parseClass(clazz),
      ],
      decorators: [
        for (final clazz in classes)
          if (_decorators.declares(clazz)) _decorators.parseClass(clazz),
      ],
    );
  }
}
