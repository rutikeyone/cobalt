import 'package:cobalt/src/errors/cobalt_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Thrown when a decorator cannot wrap what it was registered for.
final class CobaltDecoratorError extends CobaltError {
  /// A decorator registered after [key] was already handed out in
  /// [scopeName], so earlier holders would keep the undecorated instance.
  CobaltDecoratorError.late(this.key, this.scopeName)
    : owner = null,
      super(
        '$key was already resolved in scope "$scopeName", so a decorator '
        'added now would leave whoever holds it with the undecorated '
        'instance. Decorate it before anything resolves it.',
      );

  /// A decorator for [key] in [scopeName], which does not register it.
  ///
  /// [owner] is the ancestor that registers [key], when one does.
  CobaltDecoratorError.notOwned(this.key, this.scopeName, {this.owner})
    : super(
        owner == null
            ? 'A decorator for $key in scope "$scopeName" wraps nothing: no '
                  'registration in that scope has that key.'
            : 'A decorator for $key in scope "$scopeName" wraps nothing: '
                  'scope "$owner" registers it and builds it there. Decorate '
                  'it in "$owner".',
      );

  /// A decorator of every registration of [type] in [scopeName], which
  /// registers none.
  ///
  /// [owner] is the nearest ancestor that registers [type], when one does.
  CobaltDecoratorError.notOwnedType(Type type, this.scopeName, {this.owner})
    : key = CobaltKey(type),
      super(
        owner == null
            ? 'A decorator of every $type in scope "$scopeName" wraps '
                  'nothing: no registration in that scope has that type.'
            : 'A decorator of every $type in scope "$scopeName" wraps '
                  'nothing: scope "$owner" registers it and builds it there. '
                  'Decorate it in "$owner".',
      );

  /// The key the decorator was registered for — for a decorator of a whole
  /// type, the type without a name.
  final CobaltKey key;

  /// The scope the decorator was registered in.
  final String scopeName;

  /// The ancestor that registers [key], or null.
  final String? owner;
}
