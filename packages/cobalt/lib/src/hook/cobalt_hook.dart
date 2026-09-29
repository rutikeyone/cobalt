import 'package:cobalt/src/lifecycle/cobalt_resolver.dart';

/// Runs on every instance of [T] a scope builds, and hands it on unchanged.
///
/// Registered with `CobaltScope.hookAll`. Where a decorator wraps what one
/// registration produces and must return the registration's own type, a hook
/// is for what belongs to a supertype: every `Loggable` joining a registry,
/// every `Metered` getting its meter, whatever registration built it. It
/// cannot replace the instance — a wrapper of `Loggable` is not the `Api` the
/// `Api` registration promised its callers — so it gets the instance and
/// returns nothing.
///
/// Implement it; new members are a major change.
abstract interface class CobaltHook<T extends Object> {
  /// Called with [instance] once the scope has built and taken it, before
  /// anyone receives it. [resolver] is the scope that built it.
  void onBuilt(T instance, CobaltResolver resolver);
}
