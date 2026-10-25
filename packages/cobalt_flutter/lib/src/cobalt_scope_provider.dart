import 'package:cobalt/cobalt.dart';
import 'package:cobalt_flutter/src/errors/cobalt_no_scope_error.dart';
import 'package:flutter/widgets.dart';

/// Publishes a [CobaltScope] to a widget subtree.
///
/// This only exposes a scope; it never owns one. Mount it at the root with the
/// scope returned by startup, and use [CobaltScopeWidget] further down when a
/// part of the tree needs a scope with a shorter life.
class CobaltScopeProvider extends InheritedWidget {
  /// Publishes [scope] to [child] and everything below it.
  const CobaltScopeProvider({
    required this.scope,
    required super.child,
    super.key,
  });

  /// The scope descendants resolve from.
  final CobaltScope scope;

  /// The nearest scope above [context].
  ///
  /// Throws [CobaltNoScopeError] when there is none, which is nearly always a
  /// missing provider rather than a resolution problem.
  static CobaltScope of(BuildContext context) {
    final provider = maybeOf(context);
    if (provider == null) {
      throw CobaltNoScopeError();
    }
    return provider;
  }

  /// The nearest scope above [context], or `null` if the subtree has none.
  static CobaltScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CobaltScopeProvider>()?.scope;

  @override
  bool updateShouldNotify(CobaltScopeProvider oldWidget) =>
      !identical(scope, oldWidget.scope);
}
