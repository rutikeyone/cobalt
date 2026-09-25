/// Annotations for Cobalt, a dependency injection framework for Dart and
/// Flutter.
///
/// This library holds nothing but the markers the generator reads, so a
/// package that only declares annotations does not pull in the runtime. Most
/// applications import `package:cobalt/cobalt.dart`, which re-exports all of it.
library;

export 'package:cobalt_annotations/src/cobalt_bootstrap.dart';
export 'package:cobalt_annotations/src/cobalt_decorates.dart';
export 'package:cobalt_annotations/src/cobalt_environment.dart';
export 'package:cobalt_annotations/src/cobalt_init.dart';
export 'package:cobalt_annotations/src/cobalt_inject.dart';
export 'package:cobalt_annotations/src/cobalt_lifetime.dart';
export 'package:cobalt_annotations/src/cobalt_module.dart';
export 'package:cobalt_annotations/src/cobalt_param.dart';
export 'package:cobalt_annotations/src/cobalt_provided.dart';
export 'package:cobalt_annotations/src/cobalt_scope_root.dart';
export 'package:cobalt_annotations/src/injected.dart';
export 'package:cobalt_annotations/src/named.dart';
