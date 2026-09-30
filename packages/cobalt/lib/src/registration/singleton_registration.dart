part of 'cobalt_registration.dart';

final class SingletonRegistration extends CobaltRegistration {
  SingletonRegistration({
    required super.key,
    required super.order,
    super.implementation,
    required this.value,
  });

  final Object value;
}
