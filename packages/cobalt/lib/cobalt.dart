/// Cobalt — a dependency injection framework for Dart and Flutter.
///
/// Cobalt works with or without code generation. The generator writes exactly
/// what you would write by hand, using only what this library exports, so both
/// modes share one runtime and one set of guarantees.
///
/// The starting points are [CobaltScope] for the container and
/// [CobaltApplication] for two-phase startup. For widgets, add
/// `package:cobalt_flutter/cobalt_flutter.dart`.
library;

export 'package:cobalt_annotations/cobalt_annotations.dart';

export 'package:cobalt/src/bootstrap/cobalt_application.dart';
export 'package:cobalt/src/bootstrap/cobalt_bootstrap_step.dart';
export 'package:cobalt/src/bootstrap/cobalt_scope_builder.dart';
export 'package:cobalt/src/errors/cobalt_bootstrap_error.dart';
export 'package:cobalt/src/errors/cobalt_dispose_error.dart';
export 'package:cobalt/src/errors/cobalt_dispose_failure.dart';
export 'package:cobalt/src/errors/cobalt_depends_on_error.dart';
export 'package:cobalt/src/errors/cobalt_dispose_stage.dart';
export 'package:cobalt/src/errors/cobalt_duplicate_registration_error.dart';
export 'package:cobalt/src/errors/cobalt_error.dart';
export 'package:cobalt/src/errors/cobalt_lazy_async_error.dart';
export 'package:cobalt/src/errors/cobalt_not_parameterized_error.dart';
export 'package:cobalt/src/errors/cobalt_not_ready_error.dart';
export 'package:cobalt/src/errors/cobalt_override_error.dart';
export 'package:cobalt/src/errors/cobalt_param_required_error.dart';
export 'package:cobalt/src/errors/cobalt_param_type_error.dart';
export 'package:cobalt/src/errors/cobalt_not_registered_error.dart';
export 'package:cobalt/src/errors/cobalt_scope_state_error.dart';
export 'package:cobalt/src/factory/cobalt_async_factory.dart';
export 'package:cobalt/src/factory/cobalt_factory.dart';
export 'package:cobalt/src/factory/cobalt_param_factory.dart';
export 'package:cobalt/src/graph/cobalt_cycle_error.dart';
export 'package:cobalt/src/graph/topological_sort.dart';
export 'package:cobalt/src/key/cobalt_key.dart';
export 'package:cobalt/src/lifecycle/cobalt_injectable.dart';
export 'package:cobalt/src/lifecycle/cobalt_resolver.dart';
export 'package:cobalt/src/lifecycle/async_disposable.dart';
export 'package:cobalt/src/lifecycle/async_initializable.dart';
export 'package:cobalt/src/lifecycle/disposable.dart';
export 'package:cobalt/src/logging/cobalt_developer_log_sink.dart';
export 'package:cobalt/src/logging/cobalt_error_observer.dart';
export 'package:cobalt/src/logging/cobalt_error_report.dart';
export 'package:cobalt/src/logging/cobalt_error_sink.dart';
export 'package:cobalt/src/logging/cobalt_log_level.dart';
export 'package:cobalt/src/logging/cobalt_log_observer.dart';
export 'package:cobalt/src/logging/cobalt_log_record.dart';
export 'package:cobalt/src/logging/cobalt_log_sink.dart';
export 'package:cobalt/src/logging/cobalt_multi_sink.dart';
export 'package:cobalt/src/logging/cobalt_print_log_sink.dart';
export 'package:cobalt/src/logging/cobalt_recording_observer.dart';
export 'package:cobalt/src/observer/cobalt_event_kind.dart';
export 'package:cobalt/src/observer/cobalt_observer.dart';
export 'package:cobalt/src/observer/cobalt_scope_ref.dart';
export 'package:cobalt/src/overrides/cobalt_override.dart';
export 'package:cobalt/src/overrides/cobalt_param_override.dart';
export 'package:cobalt/src/scope/cobalt_registration_kind.dart';
export 'package:cobalt/src/scope/cobalt_scope.dart';
export 'package:cobalt/src/scope/cobalt_scope_state.dart';
