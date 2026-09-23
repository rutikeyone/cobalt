import 'package:cobalt/src/bootstrap/cobalt_bootstrap_step.dart';
import 'package:cobalt/src/bootstrap/cobalt_scope_builder.dart';
import 'package:cobalt/src/errors/cobalt_bootstrap_error.dart';
import 'package:cobalt/src/lifecycle/async_disposable.dart';
import 'package:cobalt/src/lifecycle/disposable.dart';
import 'package:cobalt/src/observer/cobalt_observer.dart';
import 'package:cobalt/src/overrides/cobalt_override.dart';
import 'package:cobalt/src/scope/cobalt_scope.dart';

/// Runs the two-phase startup and hands back the root scope.
///
/// Phase 0 is [CobaltBootstrapStep]s, run one after another before any
/// container exists. Phase 1 builds the root scope from an
/// [CobaltScopeBuilder] and awaits its async initializers as a graph.
final class CobaltApplication {
  const CobaltApplication._();

  /// Runs [bootstrap], assembles the root scope from [root], initializes it
  /// and returns it active.
  ///
  /// Steps that ran are adopted by the root scope before anything is
  /// registered, so a step holding a resource is disposed with the scope —
  /// and, being adopted first, disposed last, after everything that was built
  /// on top of the platform it set up.
  ///
  /// A failing bootstrap step aborts startup: later steps do not run, the
  /// container is never assembled, and the failure is rethrown as
  /// [CobaltBootstrapError] naming the step. Steps that already ran are
  /// released first, in reverse order, since there is no scope to hand them
  /// to.
  ///
  /// [overrides] replace registrations [root] makes; each is checked to have
  /// replaced something once [root] has run. See [CobaltOverride].
  ///
  /// The caller owns the returned scope and must dispose it. In Code-Gen Mode
  /// the generated `$startCobalt()` is this call with the generated container,
  /// bootstrap list and root name already filled in.
  static Future<CobaltScope> start({
    required CobaltScopeBuilder root,
    List<CobaltBootstrapStep> bootstrap = const [],
    String rootName = 'root',
    List<CobaltObserver> observers = const [],
    List<CobaltOverride<Object>> overrides = const [],
  }) async {
    final completed = <CobaltBootstrapStep>[];

    for (final step in bootstrap) {
      final elapsed = Stopwatch()..start();
      _notify(
        observers,
        (observer) => observer.onBootstrapStepStarted(step.name),
      );
      try {
        await step.run();
      } catch (error, stackTrace) {
        _notify(
          observers,
          (observer) =>
              observer.onBootstrapStepFailed(step.name, error, stackTrace),
        );
        await _release(completed, observers);
        throw CobaltBootstrapError(step.name, error, stackTrace);
      }
      _notify(
        observers,
        (observer) =>
            observer.onBootstrapStepCompleted(step.name, elapsed.elapsed),
      );
      completed.add(step);
    }

    final scope = CobaltScope.root(
      name: rootName,
      observers: observers,
      overrides: overrides,
    );
    for (final step in completed) {
      scope.adopt(step);
    }

    scope.runBuilder(root);
    await scope.init();
    return scope;
  }

  static Future<void> _release(
    List<CobaltBootstrapStep> completed,
    List<CobaltObserver> observers,
  ) async {
    for (final step in completed.reversed) {
      try {
        if (step is AsyncDisposable) {
          await (step as AsyncDisposable).dispose();
        } else if (step is Disposable) {
          (step as Disposable).dispose();
        }
      } catch (error, stackTrace) {
        // The bootstrap failure is the headline: a step that also fails to
        // release cannot be reported through CobaltBootstrapError without
        // masking it. Observers are the channel that does not have to choose.
        _notify(
          observers,
          (observer) => observer.onBootstrapStepReleaseFailed(
            step.name,
            error,
            stackTrace,
          ),
        );
      }
    }
  }

  static void _notify(
    List<CobaltObserver> observers,
    void Function(CobaltObserver observer) event,
  ) {
    for (final observer in observers) {
      try {
        event(observer);
      } catch (_) {
        // Watching must not break what it watches.
      }
    }
  }
}
