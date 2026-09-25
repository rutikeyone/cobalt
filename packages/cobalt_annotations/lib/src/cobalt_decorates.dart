import 'package:meta/meta_meta.dart';

/// Wraps what the container hands out for [target] in the annotated class.
///
/// The generated form of `CobaltScope.decorate`. The class is not registered
/// itself: it is built around the instance the registration of [target]
/// produces, and callers of `get<Target>()` receive the wrapper.
///
/// ```dart
/// @CobaltDecorates(ApiClient)
/// class LoggingApi implements ApiClient {
///   LoggingApi(this._inner, this._log);
///
///   final ApiClient _inner;
///   final Logger _log;
/// }
/// ```
///
/// The class must be a subtype of [target] and take exactly one constructor
/// parameter of that type — the instance being wrapped. Every other parameter
/// is resolved from the scope that owns the registration, with [Named]
/// selecting a named one.
///
/// Two decorators of one registration need an [order]: the lower one is
/// applied first and ends up innermost. The generator refuses to guess which
/// wraps which.
///
/// `@CobaltEnvironment` restricts it to one build like any registration. A
/// decorator is a wrapper, not an owner: the scope closes the instance it
/// wraps and never the decorator, so it holds no resources of its own.
@Target({TargetKind.classType})
class CobaltDecorates {
  /// Creates the annotation for [target], optionally a named registration.
  const CobaltDecorates(this.target, {this.name, this.order});

  /// The registered type to wrap — the exposed type when the registration
  /// uses `exposeAs`.
  final Type target;

  /// The name of the registration to wrap, when it has one.
  final String? name;

  /// Where this decorator sits among others of the same registration; the
  /// lowest is innermost. Required when there is more than one.
  final int? order;
}
