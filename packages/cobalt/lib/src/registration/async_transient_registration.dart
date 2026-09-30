part of 'cobalt_registration.dart';

final class AsyncTransientRegistration extends CobaltRegistration {
  AsyncTransientRegistration({
    required super.key,
    required super.order,
    super.implementation,
    required this.factory,
  });

  final CobaltAsyncFactory<Object> factory;
}
