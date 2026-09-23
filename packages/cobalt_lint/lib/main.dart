/// Analyzer plugin with lint rules for Cobalt.
///
/// Every rule reads annotations through `cobalt_analyzer`, the same layer the
/// generator uses, so the IDE and the build agree on what a declaration means.
library;

import 'package:cobalt_lint/src/rules/bootstrap_requires_run_method.dart';
import 'package:cobalt_lint/src/rules/bootstrap_step_cannot_inject.dart';
import 'package:cobalt_lint/src/rules/dependency_cycle.dart';
import 'package:cobalt_lint/src/rules/dependency_is_not_registered.dart';
import 'package:cobalt_lint/src/rules/environment_needs_a_registration.dart';
import 'package:cobalt_lint/src/rules/init_requires_init_method.dart';
import 'package:cobalt_lint/src/rules/injected_field_needs_an_injectable.dart';
import 'package:cobalt_lint/src/rules/injectable_must_be_constructible.dart';
import 'package:cobalt_lint/src/rules/injected_field_must_be_late_final.dart';
import 'package:cobalt_lint/src/rules/lazy_registration_injected_synchronously.dart';
import 'package:cobalt_lint/src/rules/missing_injection_mixin.dart';
import 'package:cobalt_lint/src/rules/param_needs_an_injectable.dart';
import 'package:cobalt_lint/src/rules/registration_is_never_released.dart';
import 'package:cobalt_lint/src/rules/resource_is_never_closed.dart';
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

/// The plugin instance the analysis server loads.
///
/// The server generates code that imports this library and reads this
/// variable, which is why the entry point must be `lib/main.dart` and why pub
/// reports a name-mismatch warning for this package.
final plugin = _CobaltPlugin();

class _CobaltPlugin extends Plugin {
  @override
  String get name => 'cobalt_lint';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(BootstrapRequiresRunMethod());
    registry.registerWarningRule(BootstrapStepCannotInject());
    registry.registerWarningRule(DependencyCycle());
    registry.registerWarningRule(DependencyIsNotRegistered());
    registry.registerWarningRule(EnvironmentNeedsARegistration());
    registry.registerWarningRule(InitRequiresInitMethod());
    registry.registerWarningRule(InjectableMustBeConstructible());
    registry.registerWarningRule(InjectedFieldMustBeLateFinal());
    registry.registerWarningRule(InjectedFieldNeedsAnInjectable());
    registry.registerWarningRule(LazyRegistrationInjectedSynchronously());
    registry.registerWarningRule(MissingInjectionMixin());
    registry.registerWarningRule(ParamNeedsAnInjectable());
    registry.registerWarningRule(RegistrationIsNeverReleased());
    registry.registerWarningRule(ResourceIsNeverClosed());
  }
}
