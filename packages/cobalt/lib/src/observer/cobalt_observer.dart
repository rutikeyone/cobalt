import 'package:cobalt/src/errors/cobalt_dispose_failure.dart';
import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/scope/cobalt_registration_kind.dart';
import 'package:cobalt/src/observer/cobalt_scope_ref.dart';

/// Watches what a scope tree does.
///
/// Every method does nothing by default, so an observer overrides only what it
/// cares about and a new event added later does not break it. Pass observers
/// to `CobaltScope.root` or `CobaltApplication.start`; a child scope inherits
/// its parent's observers.
///
/// Callbacks are invoked synchronously, in the middle of the work they
/// describe. Keep them cheap, and do not resolve, register or dispose from
/// inside one — which is why they receive [CobaltScopeRef] and [CobaltKey]
/// rather than live objects.
///
/// An exception thrown from a callback is caught and ignored: watching must
/// not be able to break the graph it is watching.
///
/// Resolution itself is not reported. A cache hit is the hot path, and an
/// event per `get` would be noise; what is worth seeing is an instance being
/// *built*, which [onInstanceCreated] covers.
abstract base class CobaltObserver {
  /// Creates an observer.
  const CobaltObserver();

  /// A child scope was pushed.
  void onScopePushed(CobaltScopeRef scope) {}

  /// The registration of [key] was skipped, because an override handed to
  /// [scope] already holds it.
  ///
  /// Reported at the moment the real registration is attempted, so a graph
  /// running with a replacement never does so silently.
  void onRegistrationOverridden(CobaltScopeRef scope, CobaltKey key) {}

  /// `init()` started, with [levels] levels of async singletons to build.
  ///
  /// Not called when the scope has no async registrations.
  void onScopeInitStarted(CobaltScopeRef scope, int levels) {}

  /// Every async singleton finished building.
  void onScopeInitCompleted(CobaltScopeRef scope, Duration took) {}

  /// `init()` failed. The error is also thrown to whoever called `init()`.
  void onScopeInitFailed(
    CobaltScopeRef scope,
    Object error,
    StackTrace stackTrace,
  ) {}

  /// An instance was constructed.
  ///
  /// [kind] is the registration it came from, and [retained] whether the scope
  /// will dispose it — false for transients and parameterized factories, whose
  /// caller owns them. Both are reported because they answer different
  /// questions: one is how long the thing lives, the other is who closes it.
  ///
  /// A value handed to `registerSingleton` never reaches here: it was built by
  /// whoever called it and handed over already made, so the scope has nothing
  /// to report constructing. `registerEagerSingleton` does reach here, because
  /// the scope builds it.
  void onInstanceCreated(
    CobaltScopeRef scope,
    CobaltKey key, {
    required CobaltRegistrationKind kind,
    required bool retained,
  }) {}

  /// An owned instance was disposed without error. [label] is its type.
  void onInstanceDisposed(CobaltScopeRef scope, String label) {}

  /// Teardown began. The scope is already unusable at this point.
  void onScopeDisposeStarted(CobaltScopeRef scope) {}

  /// Teardown finished, always — [failures] is what it could not release.
  void onScopeDisposed(
    CobaltScopeRef scope,
    Duration took,
    List<CobaltDisposeFailure> failures,
  ) {}

  /// A bootstrap step is about to run.
  void onBootstrapStepStarted(String step) {}

  /// A bootstrap step finished.
  void onBootstrapStepCompleted(String step, Duration took) {}

  /// A bootstrap step threw. Startup is aborted and earlier steps released.
  void onBootstrapStepFailed(
    String step,
    Object error,
    StackTrace stackTrace,
  ) {}

  /// Releasing an already-completed step failed while rolling startup back.
  ///
  /// This one exists because the alternative is silence: the rollback cannot
  /// report through `CobaltBootstrapError` without masking the failure that
  /// caused it, so before observers existed the error was dropped.
  void onBootstrapStepReleaseFailed(
    String step,
    Object error,
    StackTrace stackTrace,
  ) {}
}
