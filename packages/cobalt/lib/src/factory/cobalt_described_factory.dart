/// A factory that names the class it builds, for descriptions of the graph.
///
/// A key often hides its implementation: `ApiClient` is `FakeApiClient` in one
/// build and `LiveApiClient` in another, and nothing about the registration
/// says which without building it. A factory that implements this says so, and
/// `describeGraph` in `cobalt_test` shows it — which is what makes one
/// snapshot per environment worth keeping.
///
/// Every factory the generator writes implements it. Implement it on a
/// hand-written factory when its key does not already say what it builds.
abstract interface class CobaltDescribedFactory {
  /// The class this factory builds, as a reader would name it.
  String get implementation;
}
