import 'package:cobalt/cobalt.dart';
import 'package:cobalt_flutter/src/cobalt_scope_provider.dart';
import 'package:flutter/widgets.dart';

/// Resolves [T] with `getAsync` and builds from it once it is there.
///
/// Made for a lazy async registration: something expensive that lives as long
/// as its scope but is wanted by few screens. The first screen that asks
/// builds it and shows [loading] meanwhile; every later one finds it built and
/// renders straight away, without a frame of [loading].
///
/// ```dart
/// CobaltAsyncBuilder<SearchEngine>(
///   loading: const Center(child: CircularProgressIndicator()),
///   errorBuilder: (context, error, retry) => RetryView(onRetry: retry),
///   builder: (context, engine) => SearchScreen(engine: engine),
/// )
/// ```
///
/// Rebuilding the parent does not start the resolution again: it is held in
/// this widget's state, and restarts only when the nearest scope or [name]
/// changes. A failed build is not remembered by the scope, so `retry` really
/// does try again.
class CobaltAsyncBuilder<T extends Object> extends StatefulWidget {
  /// Creates a widget that builds from [T] once it resolves.
  const CobaltAsyncBuilder({
    required this.builder,
    this.name,
    this.loading,
    this.errorBuilder,
    super.key,
  });

  /// Builds the subtree from the resolved instance.
  final Widget Function(BuildContext context, T value) builder;

  /// The registration's name, when it has one.
  final String? name;

  /// Shown while [T] is being built.
  final Widget? loading;

  /// Shown when building [T] throws. `retry` asks the scope again.
  ///
  /// Without it the error is rethrown during build, surfacing through the
  /// usual Flutter error handling — the same rule `CobaltScopeWidget` follows.
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
  errorBuilder;

  @override
  State<CobaltAsyncBuilder<T>> createState() => _CobaltAsyncBuilderState<T>();
}

class _CobaltAsyncBuilderState<T extends Object>
    extends State<CobaltAsyncBuilder<T>> {
  CobaltScope? _scope;
  T? _value;
  Object? _error;
  var _attempt = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = CobaltScopeProvider.of(context);
    if (identical(scope, _scope)) return;
    _scope = scope;
    _resolve();
  }

  @override
  void didUpdateWidget(CobaltAsyncBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) _resolve();
  }

  void _resolve() {
    final scope = _scope!;
    final attempt = ++_attempt;
    _value = null;
    _error = null;

    try {
      _value = scope.get<T>(name: widget.name);
      return;
    } on Object catch (error) {
      if (error is! CobaltLazyAsyncError && error is! CobaltNotReadyError) {
        _error = error;
        return;
      }
    }

    scope
        .getAsync<T>(name: widget.name)
        .then(
          (value) {
            if (!mounted || attempt != _attempt) return;
            setState(() => _value = value);
          },
          onError: (Object error) {
            if (!mounted || attempt != _attempt) return;
            setState(() => _error = error);
          },
        );
  }

  void _retry() => setState(_resolve);

  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value != null) return widget.builder(context, value);

    final error = _error;
    if (error != null) {
      final errorBuilder = widget.errorBuilder;
      if (errorBuilder == null) throw error;
      return errorBuilder(context, error, _retry);
    }

    return widget.loading ?? const SizedBox.shrink();
  }
}
