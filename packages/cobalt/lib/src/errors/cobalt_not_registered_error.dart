import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when nothing matching the requested key exists in the scope or any
/// of its ancestors.
///
/// A common cause is asking a parent for something only a child registered:
/// resolution walks upwards, never down.
final class CobaltNotRegisteredError extends CobaltError {
  /// Creates an error for the missing [key], reported from [scopeName].
  ///
  /// [resolving] is what was being built when the key was asked for, outermost
  /// first. It turns "Config is not registered" into the sentence that also
  /// names the class that wanted it, which is the one you have to change.
  ///
  /// [registeredElsewhere] and [sameType] are what the scope tree knows
  /// about the key elsewhere, and turn the message into a hint at the fix.
  CobaltNotRegisteredError(
    this.key,
    this.scopeName, {
    this.resolving = const [],
    this.whileBuilding = false,
    this.registeredElsewhere = const [],
    this.sameType = const [],
  }) : super(
         _message(
           key,
           scopeName,
           resolving,
           whileBuilding,
           registeredElsewhere,
           sameType,
         ),
       );

  /// The key that could not be resolved.
  final CobaltKey key;

  /// The scope the resolution started from.
  final String scopeName;

  /// The registrations under construction when this was asked for.
  final List<CobaltKey> resolving;

  /// Whether a scope builder was still running when this was asked for.
  ///
  /// Then the answer is probably "not yet" rather than "not at all", and the
  /// message says so. Outside that window the same sentence would be a guess.
  final bool whileBuilding;

  /// Names of scopes in the same tree, neither this scope nor one of its
  /// ancestors, that register [key]: at most three, depth first from the
  /// root.
  ///
  /// Resolution walks up, never down, so a key registered only in a child or
  /// a sibling scope is invisible from here.
  final List<String> registeredElsewhere;

  /// Keys visible from this scope with the type of [key] and a different
  /// name, sorted by their string form.
  ///
  /// Usually the name was misspelled or left out.
  final List<CobaltKey> sameType;

  static String _message(
    CobaltKey key,
    String scopeName,
    List<CobaltKey> resolving,
    bool whileBuilding,
    List<String> registeredElsewhere,
    List<CobaltKey> sameType,
  ) {
    final where =
        '$key is not registered in scope "$scopeName" or its ancestors.';
    final when = whileBuilding
        ? ' The scope is still being built, so a registration made further '
              'down build() is not there yet — an eager registerSingleton '
              'resolves at once, while a lazy one would have waited.'
        : '';
    final path = resolving.isEmpty
        ? ''
        : ' Resolving: ${[...resolving, key].join(' -> ')}.';
    return '$where$when$path'
        '${_hints(key, scopeName, whileBuilding, registeredElsewhere, sameType)}';
  }

  static String _hints(
    CobaltKey key,
    String scopeName,
    bool whileBuilding,
    List<String> registeredElsewhere,
    List<CobaltKey> sameType,
  ) {
    final hints = StringBuffer();
    if (registeredElsewhere.isNotEmpty) {
      final scopes = registeredElsewhere.map((name) => '"$name"').join(', ');
      final one = registeredElsewhere.length == 1;
      hints.write(
        ' It is registered in ${one ? 'scope' : 'scopes'} $scopes, which '
        '${one ? 'is' : 'are'} not above "$scopeName": resolution walks up, '
        'never down.',
      );
    }
    if (sameType.isNotEmpty) {
      hints.write(' The same type is registered as ${sameType.join(', ')}.');
    }
    if (registeredElsewhere.isEmpty && sameType.isEmpty && !whileBuilding) {
      hints.write(
        ' Nothing in this scope tree registers $key. Register it, or if it is '
        'a @cobaltInject class, run build_runner again.',
      );
    }
    return hints.toString();
  }
}
