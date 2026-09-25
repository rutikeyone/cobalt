import 'package:cobalt/cobalt.dart';
import 'package:cobalt_flutter/src/cobalt_scope_widget.dart';
import 'package:flutter/widgets.dart';

/// A stateless widget that owns a scope for as long as it is mounted.
///
/// Collapses the three pieces an owned scope otherwise needs — a scope builder,
/// an [CobaltScopeWidget] wrapper and a separate child widget — into one class.
/// Declare what the scope holds in [registerScope] and the UI in [buildScoped];
/// the scope is pushed on mount and disposed on unmount.
///
/// ```dart
/// class NoteDetailScreen extends CobaltScopedWidget {
///   const NoteDetailScreen({super.key});
///
///   @override
///   void registerScope(CobaltScope scope) =>
///       scope.registerLazySingleton<NoteDraft>(const NoteDraftFactory());
///
///   @override
///   Widget buildScoped(BuildContext context) =>
///       Text(context.cobalt<NoteDraft>().text);
/// }
/// ```
///
/// [buildScoped] runs below the scope, so `context.cobalt<T>()` there resolves
/// from it. Use [CobaltScopeWidget] directly when the scope has to wrap only
/// part of a subtree rather than the whole widget.
abstract class CobaltScopedWidget extends StatelessWidget {
  /// Creates a widget owning a scope.
  const CobaltScopedWidget({super.key});

  /// Name of the scope, defaulting to this widget's own type.
  String? get scopeName => null;

  /// Shown while the scope initializes, when it registers async singletons.
  Widget? get loading => null;

  /// Shown when initialization fails. Without it the error is rethrown.
  Widget Function(BuildContext context, Object error)? get errorBuilder => null;

  /// Replacements for registrations [registerScope] makes, produced each time
  /// the scope is created. See [CobaltScopeWidget.overrides].
  List<CobaltOverride<Object>> Function()? get overrides => null;

  /// Declares what this widget's scope holds.
  void registerScope(CobaltScope scope);

  /// Builds the UI, with the scope available on [context].
  Widget buildScoped(BuildContext context);

  @override
  Widget build(BuildContext context) => CobaltScopeWidget(
    name: scopeName ?? runtimeType.toString(),
    builder: CobaltWidgetScopeBuilder(this),
    loading: loading,
    errorBuilder: errorBuilder,
    overrides: overrides,
    child: CobaltScopedChild(this),
  );
}

/// Adapts an [CobaltScopedWidget] to [CobaltScopeBuilder].
///
/// An object rather than a closure, so nothing is captured beyond the widget
/// itself and the builder compares by the widget it wraps.
final class CobaltWidgetScopeBuilder implements CobaltScopeBuilder {
  /// Wraps [widget] so its `registerScope` can be passed as a builder.
  const CobaltWidgetScopeBuilder(this.widget);

  /// The widget whose scope this builds.
  final CobaltScopedWidget widget;

  @override
  void build(CobaltScope scope) => widget.registerScope(scope);
}

/// Renders an [CobaltScopedWidget]'s content below its scope.
final class CobaltScopedChild extends StatelessWidget {
  /// Renders the content of [owner].
  const CobaltScopedChild(this.owner, {super.key});

  /// The widget whose [CobaltScopedWidget.buildScoped] this calls.
  final CobaltScopedWidget owner;

  @override
  Widget build(BuildContext context) => owner.buildScoped(context);
}
