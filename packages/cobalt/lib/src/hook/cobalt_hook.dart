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
/// Extend it and override what you need; both methods do nothing by default.
/// It is a base class, as `CobaltObserver` is, so a new method arrives with an
/// empty body and a hook written against an older release keeps compiling.
abstract base class CobaltHook<T extends Object> {
  /// Creates the base.
  const CobaltHook();

  /// Called with [instance] once the scope has built and taken it, before
  /// anyone receives it. [resolver] is the scope that built it.
  void onBuilt(T instance, CobaltResolver resolver) {}

  /// Called when the scope releases [instance], before it is closed.
  ///
  /// Only for what the scope keeps — singletons of every kind — since those
  /// are the instances it releases; a transient is the caller's and never
  /// comes back. The undo of [onBuilt]: what joined a registry leaves it here,
  /// while the instance is still usable. A throw is reported with the scope's
  /// other teardown failures and does not stop the rest.
  void onReleased(T instance) {}
}
