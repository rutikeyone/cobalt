import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when `getWithParam` is handed a value the registered factory cannot
/// take.
///
/// The registration's parameter type is not part of its key, so a wrong one
/// resolves the right registration and only fails deep inside the factory, as
/// a cast error naming a parameter the caller never wrote. Cobalt checks the
/// value first so the message can name the registration and both types.
///
/// Nothing else can catch this: parameterized factories have no annotation, so
/// neither the generator nor the lint plugin knows they exist. This message is
/// also the only way to discover what a registration expects — a scope reports
/// its keys, never the parameter behind one.
final class CobaltParamTypeError extends CobaltError {
  /// Creates an error for [key], which takes [expected] but was given
  /// [actual].
  CobaltParamTypeError(this.key, this.expected, this.actual)
    : super('$key takes a parameter of type $expected, but $actual was given.');

  /// The registration that was resolved.
  final CobaltKey key;

  /// The parameter type the factory was registered with.
  final Type expected;

  /// The runtime type of the value that was passed.
  final Type actual;
}
