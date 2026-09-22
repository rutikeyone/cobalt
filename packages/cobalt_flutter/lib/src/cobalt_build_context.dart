import 'package:cobalt/cobalt.dart';
import 'package:cobalt_flutter/src/cobalt_scope_provider.dart';
import 'package:flutter/widgets.dart';

/// Resolves dependencies from the nearest [CobaltScopeProvider].
///
/// Every member here reads an inherited widget, so none of them may be called
/// from `initState` or a constructor — Flutter asserts on that. Resolve in
/// `build`, or in `didChangeDependencies` when the result has to be stored,
/// which is also where a subscription belongs:
///
/// ```dart
/// @override
/// void didChangeDependencies() {
///   super.didChangeDependencies();
///   final session = context.cobalt<SessionManager>();
///   if (identical(session, _session)) return;
///   _session?.removeListener(_onChanged);
///   _session = session..addListener(_onChanged);
/// }
/// ```
///
/// A `late final` field initialized from `context` is fine as long as it is
/// first read during `build`, since that is when the lazy initializer runs.
extension CobaltBuildContext on BuildContext {
  /// The nearest scope above this context.
  CobaltScope get cobaltScope => CobaltScopeProvider.of(this);

  /// Resolves [T] from the nearest scope.
  T cobalt<T extends Object>({String? name}) =>
      CobaltScopeProvider.of(this).get<T>(name: name);

  /// Resolves every registration of [T] visible from the nearest scope.
  List<T> cobaltAll<T extends Object>() =>
      CobaltScopeProvider.of(this).getAll<T>();

  /// Builds [T] from a parameterized factory, passing [param].
  T cobaltWithParam<T extends Object, P extends Object>(
    P param, {
    String? name,
  }) => CobaltScopeProvider.of(this).getWithParam<T, P>(param, name: name);

  /// Resolves [T] from the nearest scope with `getAsync`, building a lazy
  /// async registration the first time it is asked for.
  ///
  /// To build a subtree from the result, `CobaltAsyncBuilder` holds the
  /// future across rebuilds and handles loading and failure.
  Future<T> cobaltAsync<T extends Object>({String? name}) =>
      CobaltScopeProvider.of(this).getAsync<T>(name: name);
}
