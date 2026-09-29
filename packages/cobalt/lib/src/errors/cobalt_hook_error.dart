import 'package:cobalt/src/errors/cobalt_error.dart';

/// Thrown when a hook is added to a scope that has already built something.
final class CobaltHookError extends CobaltError {
  /// A hook of every [type] added to [scopeName] after it, or a scope below
  /// it, built an instance — which the hook would silently have missed.
  CobaltHookError.late(this.type, this.scopeName)
    : super(
        'A hook of every $type was added to scope "$scopeName" after it, or '
        'a scope below it, had built instances; those would never pass '
        'through it. Add hooks where the scope is composed, before anything '
        'is resolved.',
      );

  /// The type the hook was added for.
  final Type type;

  /// The scope the hook was added to.
  final String scopeName;
}
