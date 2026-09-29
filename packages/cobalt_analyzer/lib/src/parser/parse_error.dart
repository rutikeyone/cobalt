import 'package:analyzer/dart/element/element.dart';

/// A declaration Cobalt cannot turn into a registration.
///
/// Carries the offending [element] so the generator can point `build_runner`
/// at the exact source location.
final class CobaltParseError implements Exception {
  CobaltParseError(this.message, this.element);

  final String message;
  final Element element;

  @override
  String toString() => 'CobaltParseError: $message';
}
