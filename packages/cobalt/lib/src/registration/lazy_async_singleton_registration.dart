part of 'cobalt_registration.dart';

final class LazyAsyncSingletonRegistration extends CobaltRegistration {
  LazyAsyncSingletonRegistration({
    required super.key,
    required super.order,
    required this.factory,
    this.teardown,
  });

  final CobaltAsyncFactory<Object> factory;
  final CobaltTeardown? teardown;

  Object? instance;

  Future<Object>? inFlight;
}
