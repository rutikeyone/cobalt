import 'package:cobalt/cobalt.dart';

/// Thrown when nothing publishes a scope above the widget asking for one.
///
/// Usually a missing provider at the root. The other cause is worth knowing
/// because it looks nothing like one: a route pushed with `Navigator.push` is
/// built by the navigator, which sits *above* any provider mounted inside a
/// screen — so a widget that resolved fine in place throws the moment the same
/// code runs on a pushed route. Read the scope where the push happens and pass
/// it in, rather than reading it inside the pushed widget.
final class CobaltNoScopeError extends CobaltError {
  /// Creates the error.
  CobaltNoScopeError()
    : super(
        'No CobaltScopeProvider found above this widget. Wrap the subtree in '
        'CobaltScopeProvider or CobaltScopeWidget — and if this is a pushed '
        'route, remember the navigator builds it above the provider, so pass '
        'the scope in instead of reading it here.',
      );
}
