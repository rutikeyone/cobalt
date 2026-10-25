import 'package:cobalt_annotations/src/cobalt_provided.dart';
import 'package:meta/meta_meta.dart';

/// Names the root scope and makes the generator emit a start function.
///
/// Annotate any one class in the package — it is a marker, nothing is
/// registered from it. The generator then emits `cobaltRootScopeName` and
/// `startCobalt()`, which wires the container, the bootstrap list and the name
/// together:
///
/// ```dart
/// @CobaltScopeRoot(name: 'app')
/// class AppScope {
///   const AppScope();
/// }
///
/// final scope = await startCobalt();
/// ```
///
/// Without the annotation the root scope is called `root`. Two annotated
/// classes in one package is a generation error, since the package can only
/// have one root.
@Target({TargetKind.classType})
class CobaltScopeRoot {
  /// Creates an annotation naming the root scope.
  const CobaltScopeRoot({this.name = 'root', this.provides = const []});

  /// The name the root scope reports, used in error messages and when
  /// inspecting the scope tree.
  final String name;

  /// Registrations the generated container does not make, but may depend on.
  ///
  /// The generator rejects a graph where an injected dependency is registered
  /// by nothing, which is how a missing registration becomes a build failure
  /// instead of a `CobaltNotRegisteredError` at startup. It only sees this
  /// package's annotations, so anything registered by hand is invisible to it:
  /// a scope builder that wraps `CobaltRoot` and adds to it, or a
  /// provider from another package. Name those here.
  ///
  /// An element is either a `Type`, or a [CobaltProvided] when the
  /// hand-written registration is named:
  ///
  /// ```dart
  /// @CobaltScopeRoot(name: 'app', provides: [SessionManager])
  /// class AppScope {
  ///   const AppScope();
  /// }
  /// ```
  ///
  /// This is a promise, not a registration — nothing is emitted for it. Listing
  /// something nothing registers moves the failure back to startup, which is
  /// where it was before.
  final List<Object> provides;
}
