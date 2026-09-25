/// Shared static analysis layer for Cobalt.
///
/// Turns annotated Dart source into a typed intermediate representation that
/// both `cobalt_generator` and `cobalt_lint` consume, so a declaration is parsed
/// by one implementation rather than two that drift apart.
///
/// Depends on `analyzer` but deliberately not on `build` or the plugin API,
/// which is what keeps the build system out of the analysis server.
library;

export 'package:cobalt/cobalt.dart'
    show CobaltCycleError, layeredTopologicalSort;
// The IR exposes these in its own public API — `CobaltInjectableClass.lifetime`
// is an CobaltLifetime — so a reader of the model needs them to say anything
// about what it read.
export 'package:cobalt_annotations/cobalt_annotations.dart' show CobaltLifetime;

export 'package:cobalt_analyzer/src/model/bootstrap_step_class.dart';
export 'package:cobalt_analyzer/src/model/decorator_class.dart';
export 'package:cobalt_analyzer/src/model/function_ref.dart';
export 'package:cobalt_analyzer/src/model/injectable_class.dart';
export 'package:cobalt_analyzer/src/model/injected_property.dart';
export 'package:cobalt_analyzer/src/model/library_declarations.dart';
export 'package:cobalt_analyzer/src/model/provided_ref.dart';
export 'package:cobalt_analyzer/src/model/provider_ref.dart';
export 'package:cobalt_analyzer/src/model/scope_root_class.dart';
export 'package:cobalt_analyzer/src/model/type_ref.dart';
export 'package:cobalt_analyzer/src/parser/cobalt_matchers.dart';
export 'package:cobalt_analyzer/src/parser/cobalt_parser.dart';
export 'package:cobalt_analyzer/src/parser/annotation_matcher.dart';
export 'package:cobalt_analyzer/src/parser/bootstrap_parser.dart';
export 'package:cobalt_analyzer/src/parser/dart_object_reader.dart';
export 'package:cobalt_analyzer/src/parser/decorator_parser.dart';
export 'package:cobalt_analyzer/src/parser/injectable_parser.dart';
export 'package:cobalt_analyzer/src/parser/module_parser.dart';
export 'package:cobalt_analyzer/src/parser/parse_error.dart';
export 'package:cobalt_analyzer/src/parser/scope_root_parser.dart';
export 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
