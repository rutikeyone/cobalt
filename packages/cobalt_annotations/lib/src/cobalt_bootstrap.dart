import 'package:meta/meta_meta.dart';

/// Marks a phase-0 startup step, run before the container exists.
///
/// The generator collects every annotated class into `cobaltBootstrapSteps`, sorted
/// by [order] and then by class name so the list is stable across builds.
/// Steps run strictly one after another — this phase is for work that must
/// finish before anything can be resolved, such as `WidgetsFlutterBinding`,
/// FFI setup or reading a config file.
///
/// Nothing can be injected into a bootstrap step, because there is no
/// container yet. A constructor with required parameters is rejected at build
/// time and flagged in the IDE by `cobalt_bootstrap_step_cannot_inject`. Work
/// that needs dependencies belongs in an [CobaltInit] service instead.
///
/// ```dart
/// @CobaltBootstrap(order: -10)
/// class BindPlatform implements CobaltBootstrapStep {
///   BindPlatform();
///
///   @override
///   String get name => 'bind-platform';
///
///   @override
///   void run() => WidgetsFlutterBinding.ensureInitialized();
/// }
/// ```
@Target({TargetKind.classType})
class CobaltBootstrap {
  /// Creates an annotation marking a phase-0 startup step.
  const CobaltBootstrap({this.order = 0});

  /// Position in the bootstrap sequence; lower runs earlier, and negative
  /// values are the way to put a step ahead of the default 0.
  final int order;
}

/// Marks a phase-0 startup step with the default order.
const cobaltBootstrap = CobaltBootstrap();
