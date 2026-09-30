import 'package:meta/meta_meta.dart';

/// Adds the annotated `CobaltHook` to the generated root scope — the
/// generated form of `CobaltScope.hookAll`.
///
/// The hook runs on every instance of its type argument that the root scope,
/// or any scope below it, builds: the way to reach whatever implements a
/// supertype, whichever registration built it. It hands the instance on
/// unchanged.
///
/// ```dart
/// @cobaltHookAll
/// final class JoinRegistry extends CobaltHook<Loggable> {
///   const JoinRegistry();
///
///   @override
///   void onBuilt(Loggable instance, CobaltResolver resolver) =>
///       resolver.get<LogRegistry>().add(instance);
/// }
/// ```
///
/// The class needs a constructor without required parameters: hooks are
/// added before anything is built, so there is nothing to inject yet — what
/// the hook needs, it resolves from the `resolver` it is handed. Several hooks
/// are added by [order], then by class name. `@CobaltEnvironment` restricts
/// one to a build like any registration.
@Target({TargetKind.classType})
class CobaltHookAll {
  /// Creates an annotation adding a hook to the generated root scope.
  const CobaltHookAll({this.order = 0});

  /// Its place among the generated hooks; lower is added, and runs, first.
  final int order;
}

/// Adds a hook to the generated root scope with the default order.
const cobaltHookAll = CobaltHookAll();
