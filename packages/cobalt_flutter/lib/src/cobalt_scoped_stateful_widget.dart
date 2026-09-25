import 'package:cobalt/cobalt.dart';
import 'package:cobalt_flutter/src/cobalt_scope_widget.dart';
import 'package:flutter/widgets.dart';

/// A stateful widget that owns a scope for as long as it is mounted.
///
/// The stateful counterpart of `CobaltScopedWidget`: the widget declares what
/// the scope holds, and its [CobaltScopedState] builds the UI below that scope.
/// `setState` rebuilds only the content — the scope is created once on mount
/// and disposed on unmount, not rebuilt.
///
/// ```dart
/// class NoteDetailScreen extends CobaltScopedStatefulWidget {
///   const NoteDetailScreen({super.key});
///
///   @override
///   void registerScope(CobaltScope scope) =>
///       scope.registerLazySingleton<NoteDraft>(const NoteDraftFactory());
///
///   @override
///   CobaltScopedState<NoteDetailScreen> createState() => _NoteDetailState();
/// }
///
/// class _NoteDetailState extends CobaltScopedState<NoteDetailScreen> {
///   @override
///   Widget buildScoped(BuildContext context) =>
///       Text(context.cobalt<NoteDraft>().text);
/// }
/// ```
abstract class CobaltScopedStatefulWidget extends StatefulWidget {
  /// Creates a widget owning a scope.
  const CobaltScopedStatefulWidget({super.key});

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

  @override
  CobaltScopedState<CobaltScopedStatefulWidget> createState();
}

/// State for an [CobaltScopedStatefulWidget].
///
/// Override [buildScoped] instead of `build`; it runs below the scope, so
/// `context.cobalt<T>()` there resolves from it.
abstract class CobaltScopedState<W extends CobaltScopedStatefulWidget>
    extends State<W> {
  /// Builds the UI, with the scope available on [context].
  Widget buildScoped(BuildContext context);

  @override
  Widget build(BuildContext context) => CobaltScopeWidget(
    name: widget.scopeName ?? widget.runtimeType.toString(),
    builder: CobaltStatefulScopeBuilder(widget),
    loading: widget.loading,
    errorBuilder: widget.errorBuilder,
    overrides: widget.overrides,
    child: CobaltScopedStateChild(this),
  );
}

/// Adapts an [CobaltScopedStatefulWidget] to [CobaltScopeBuilder].
final class CobaltStatefulScopeBuilder implements CobaltScopeBuilder {
  /// Wraps [widget] so its `registerScope` can be passed as a builder.
  const CobaltStatefulScopeBuilder(this.widget);

  /// The widget whose scope this builds.
  final CobaltScopedStatefulWidget widget;

  @override
  void build(CobaltScope scope) => widget.registerScope(scope);
}

/// Renders an [CobaltScopedState]'s content below its scope.
final class CobaltScopedStateChild extends StatelessWidget {
  /// Renders the content of [owner].
  const CobaltScopedStateChild(this.owner, {super.key});

  /// The state whose [CobaltScopedState.buildScoped] this calls.
  final CobaltScopedState<CobaltScopedStatefulWidget> owner;

  @override
  Widget build(BuildContext context) => owner.buildScoped(context);
}
