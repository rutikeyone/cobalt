part of 'cobalt_registration.dart';

final class TransientRegistration extends CobaltRegistration {
  TransientRegistration({
    required super.key,
    required super.order,
    super.implementation,
    required this.factory,
  });

  final CobaltFactory<Object> factory;
}
