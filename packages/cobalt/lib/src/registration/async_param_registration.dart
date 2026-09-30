part of 'cobalt_registration.dart';

final class AsyncParamRegistration extends CobaltRegistration {
  AsyncParamRegistration({
    required super.key,
    required super.order,
    super.implementation,
    required this.factory,
    required this.paramType,
    required this.accepts,
  });

  final CobaltAsyncParamFactory<Object, Object> factory;

  final Type paramType;

  final bool Function(Object value) accepts;
}
