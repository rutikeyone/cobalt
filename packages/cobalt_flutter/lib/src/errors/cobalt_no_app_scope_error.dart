import 'package:cobalt/cobalt.dart';

/// Thrown when nothing owns a root scope above the widget asking to restart
/// it.
///
/// [CobaltScopeProvider] publishes a scope; only `CobaltAppScope` owns one, and
/// only an owner can take it down and build it again.
final class CobaltNoAppScopeError extends CobaltError {
  /// Creates the error.
  CobaltNoAppScopeError()
    : super(
        'No CobaltAppScope found above this widget. Wrap your app in '
        'CobaltAppScope to restart its root scope; CobaltScopeProvider only '
        'publishes a scope somebody else owns.',
      );
}
