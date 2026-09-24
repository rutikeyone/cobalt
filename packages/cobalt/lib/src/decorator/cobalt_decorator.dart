import 'package:cobalt/src/lifecycle/cobalt_resolver.dart';

/// Wraps what a registration of [T] produces, without touching the class.
///
/// Registered with `CobaltScope.decorate`, on the scope that owns the
/// registration. Decorators wrap in registration order, the first innermost,
/// and see the resolver of that scope, so a decorator can resolve anything
/// the factory could.
///
/// The scope owns what the factory built, never a decorator: it closes the
/// inner instance once, and a decorator holds no resources of its own.
abstract interface class CobaltDecorator<T extends Object> {
  /// Returns what callers receive instead of [inner].
  T decorate(T inner, CobaltResolver resolver);
}
