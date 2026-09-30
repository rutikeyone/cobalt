part of 'cobalt_registration.dart';

final class ParamRegistration extends CobaltRegistration {
  ParamRegistration({
    required super.key,
    required super.order,
    super.implementation,
    required this.factory,
    required this.paramType,
    required this.accepts,
  });

  final CobaltParamFactory<Object, Object> factory;

  /// The parameter type the factory was registered with, kept for the error
  /// message — the factory itself cannot report it once erased to `Object`.
  final Type paramType;

  /// Whether a value is one this factory can take.
  ///
  /// Captured as `(value) => value is P` at registration time. A type test
  /// rather than a comparison of `Type`s, so a legitimate subtype is accepted:
  /// a factory registered for `Object` should take a `String`.
  final bool Function(Object value) accepts;
}
