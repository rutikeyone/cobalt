part of 'cobalt_registration.dart';

final class AsyncSingletonRegistration extends CobaltRegistration {
  AsyncSingletonRegistration({
    required super.key,
    required super.order,
    super.implementation,
    required this.factory,
    required this.dependsOn,
    this.teardown,
  });

  final CobaltAsyncFactory<Object> factory;
  final Set<CobaltKey> dependsOn;
  final CobaltTeardown? teardown;

  Object? instance;
  bool isReady = false;
}
