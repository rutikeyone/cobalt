import 'package:cobalt/src/bootstrap/cobalt_bootstrap_step.dart';
import 'package:cobalt/src/bootstrap/cobalt_scope_builder.dart';

/// A [CobaltScopeBuilder] for a root scope that also knows its name and its
/// bootstrap steps.
///
/// The generated `CobaltRoot` extends it, so the name given in
/// `@CobaltScopeRoot(name: ...)` reaches `CobaltApplication.start` and
/// `CobaltAppScope` without being passed:
///
/// ```dart
/// MaterialApp(builder: CobaltAppScope.builder(root: const CobaltRoot()))
/// ```
///
/// [bootstrap] is not picked up the same way, because a test that starts the
/// generated root on purpose without its steps would start running them.
/// Pass it where the steps should run:
///
/// ```dart
/// CobaltAppScope.builder(
///   root: const CobaltRoot(),
///   bootstrap: const CobaltRoot().bootstrap,
/// )
/// ```
///
/// A base class rather than an interface, so a later version can add a member
/// with a default without breaking a subclass.
abstract base class CobaltRootBuilder implements CobaltScopeBuilder {
  /// Lets subclasses be `const`.
  const CobaltRootBuilder();

  /// The name the root scope reports, in errors and in the scope tree.
  ///
  /// `CobaltApplication.start` uses it when it is not given a `rootName`.
  String get name => 'root';

  /// New instances of the bootstrap steps to run before this root is built.
  ///
  /// A method rather than a list, so every start gets steps of its own: a
  /// step holds a resource, and a restarted app or the next test must not
  /// share it.
  List<CobaltBootstrapStep> bootstrap() => const [];

  /// Whether [bootstrap] has steps, answered without creating them.
  ///
  /// The generated root says true when the package has `@CobaltBootstrap`
  /// steps, so `CobaltAppScope` can point out a root started without them.
  bool get hasBootstrap => false;
}
