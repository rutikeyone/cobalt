import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when an override replaces nothing, or cannot.
///
/// An override that no registration claims is almost always one of three
/// mistakes, and the message names whichever applies. Its type argument was
/// left out inside an `overrides:` list, where Dart infers it from the list as
/// `Object` — refused as soon as the scope is created. It was inferred from a
/// replacement written outside a list, `FakeClock` instead of `Clock`. Or the
/// key belongs to an ancestor, and an override here would only shadow it for
/// this scope while every factory up there kept the real one.
class CobaltOverrideError extends CobaltError {
  /// Creates an error for the unclaimed [key] in [scopeName].
  ///
  /// [owner] is the ancestor that registers [key], when one does.
  CobaltOverrideError(this.key, this.scopeName, {this.owner})
    : super(
        key.type == Object
            ? 'An override in scope "$scopeName" has no type argument, so '
                  'Dart inferred it from the overrides list as Object and it '
                  'would replace nothing. Name the registered type, as in '
                  'CobaltOverride<Clock>.value(...).'
            : owner == null
            ? 'The override of $key in scope "$scopeName" replaced nothing: '
                  'no registration in that scope claims it. If the type '
                  'argument was inferred from the replacement, name the '
                  'registered type, as in CobaltOverride<Base>.value(...).'
            : 'The override of $key in scope "$scopeName" replaced nothing: '
                  'scope "$owner" registers it, and its factories would keep '
                  'resolving the real one. Move the override to "$owner".',
      );

  /// The key the override was declared for.
  final CobaltKey key;

  /// The scope the override was handed to.
  final String scopeName;

  /// The ancestor that registers [key], or null when none does.
  final String? owner;
}
