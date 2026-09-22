/// Flutter bindings for Cobalt.
///
/// Re-exports the whole runtime, so a Flutter app needs this import alone.
/// [CobaltScopeProvider] publishes a scope to a subtree, [CobaltScopeWidget]
/// owns one for as long as it is mounted, and `context.cobalt<T>()` resolves
/// from whichever is nearest.
library;

export 'package:cobalt/cobalt.dart';

export 'package:cobalt_flutter/src/cobalt_app_scope.dart';
export 'package:cobalt_flutter/src/cobalt_app_scope_controller.dart';
export 'package:cobalt_flutter/src/cobalt_async_builder.dart';
export 'package:cobalt_flutter/src/cobalt_build_context.dart';
export 'package:cobalt_flutter/src/errors/cobalt_no_app_scope_error.dart';
export 'package:cobalt_flutter/src/errors/cobalt_no_scope_error.dart';
export 'package:cobalt_flutter/src/cobalt_scope_provider.dart';
export 'package:cobalt_flutter/src/cobalt_scoped_stateful_widget.dart';
export 'package:cobalt_flutter/src/cobalt_scoped_widget.dart';
export 'package:cobalt_flutter/src/cobalt_scope_widget.dart';
