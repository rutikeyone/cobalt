part of 'cobalt_registration.dart';

final class LazySingletonRegistration extends CobaltRegistration {
  LazySingletonRegistration({
    required super.key,
    required super.order,
    super.implementation,
    required this.factory,
    this.teardown,
  });

  final CobaltFactory<Object> factory;
  final CobaltTeardown? teardown;

  Object? instance;
}
