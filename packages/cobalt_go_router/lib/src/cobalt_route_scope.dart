import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/widgets.dart';

/// Owns a scope for as long as a navigation flow is open.
///
/// Mount it from a `ShellRoute.builder` and it inherits the shell's lifetime:
/// go_router keys the shell's page by the identity of the [ShellRoute] object,
/// so the subtree survives every navigation *inside* the flow and is destroyed
/// the moment the flow leaves the match list. Nothing here listens to the
/// router — the widget tree already knows.
///
/// [identity] is the one thing the router cannot decide. Two visits to
/// `/orders/1` and `/orders/2` match the same [ShellRoute], so the shell is
/// reused and the scope would be too. Pass whatever distinguishes one run of
/// the flow from another and the scope is torn down and rebuilt when it
/// changes:
///
/// ```dart
/// CobaltRouteScope(
///   name: 'checkout',
///   identity: state.pathParameters['orderId'],
///   builder: CheckoutScope(state.pathParameters['orderId']!),
///   child: child,
/// )
/// ```
///
/// Leave [identity] null when one flow instance is all there is.
///
/// Rebuilding costs a frame of [loading], because [CobaltScopeWidget] publishes
/// its scope only once `init()` has finished — even for a fully synchronous
/// graph. Teardown of the outgoing scope is not awaited either, so briefly
/// both scopes are children of the parent.
class CobaltRouteScope extends StatelessWidget {
  /// Creates a flow-scoped subtree.
  const CobaltRouteScope({
    required this.name,
    required this.builder,
    required this.child,
    this.identity,
    this.loading,
    this.errorBuilder,
    this.overrides,
    super.key,
  });

  /// What the flow is called. Becomes the scope name, with [identity]
  /// appended when there is one, so a scope tree reads `checkout:42`.
  final String name;

  /// The registrations this flow adds over its parent scope.
  final CobaltScopeBuilder builder;

  /// The flow's content — the nested navigator from `ShellRoute.builder`.
  final Widget child;

  /// What distinguishes this run of the flow from the next one.
  ///
  /// A change here disposes the current scope and builds a new one. Null means
  /// the flow has a single instance and the scope lives until the flow closes.
  final Object? identity;

  /// Shown while the flow's scope initializes.
  final Widget? loading;

  /// Builds a replacement subtree when the flow's `init()` throws.
  final Widget Function(BuildContext context, Object error)? errorBuilder;

  /// Replacements for registrations [builder] makes, produced each time the
  /// flow's scope is created. See [CobaltScopeWidget.overrides].
  final List<CobaltOverride<Object>> Function()? overrides;

  /// The scope name, with the discriminator when the flow has one.
  String get scopeName => identity == null ? name : '$name:$identity';

  @override
  Widget build(BuildContext context) => CobaltScopeWidget(
    key: ValueKey('cobalt-flow:$scopeName'),
    name: scopeName,
    builder: builder,
    loading: loading,
    errorBuilder: errorBuilder,
    overrides: overrides,
    child: child,
  );
}
