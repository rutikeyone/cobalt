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
      _hinted(() => CobaltScopeProvider.of(this).get<T>(name: name));

  /// Resolves every registration of [T] visible from the nearest scope.
  List<T> cobaltAll<T extends Object>() =>
      CobaltScopeProvider.of(this).getAll<T>();

  /// Builds [T] from a parameterized factory, passing [param].
  T cobaltWithParam<T extends Object, P extends Object>(
    P param, {
    String? name,
  }) => _hinted(
    () => CobaltScopeProvider.of(this).getWithParam<T, P>(param, name: name),
  );

  /// Resolves [T] from the nearest scope with `getAsync`, building a lazy
  /// async registration the first time it is asked for.
  ///
  /// An async transient is built anew by every call, so call it once and
  /// keep the future rather than calling it from `build`.
  ///
  /// To build a subtree from the result, `CobaltAsyncBuilder` holds the
  /// future across rebuilds and handles loading and failure.
  Future<T> cobaltAsync<T extends Object>({String? name}) =>
      _hintedAsync(() => CobaltScopeProvider.of(this).getAsync<T>(name: name));

  /// Builds [T] from an async parameterized factory, passing [param], with
  /// `getAsyncWithParam`.
  ///
  /// Every call builds a new instance. Call it once — from `initState`, or
  /// from an event — and keep the future, rather than from `build`.
  Future<T> cobaltAsyncWithParam<T extends Object, P extends Object>(
    P param, {
    String? name,
  }) => _hintedAsync(
    () =>
        CobaltScopeProvider.of(this).getAsyncWithParam<T, P>(param, name: name),
  );
}

T _hinted<T>(T Function() read) {
  try {
    return read();
  } on CobaltNotRegisteredError catch (error, stackTrace) {
    final hinted = _withWidgetHint(error);
    if (hinted == null) rethrow;
    Error.throwWithStackTrace(hinted, stackTrace);
  }
}

Future<T> _hintedAsync<T>(Future<T> Function() read) async {
  try {
    return await read();
  } on CobaltNotRegisteredError catch (error, stackTrace) {
    final hinted = _withWidgetHint(error);
    if (hinted == null) rethrow;
    Error.throwWithStackTrace(hinted, stackTrace);
  }
}

CobaltNotRegisteredError? _withWidgetHint(CobaltNotRegisteredError error) {
  if (error.hint != null ||
      error.resolving.isNotEmpty ||
      error.registeredElsewhere.isEmpty) {
    return null;
  }
  final scopes = error.registeredElsewhere.map((name) => '"$name"').join(', ');
  return CobaltNotRegisteredError(
    error.key,
    error.scopeName,
    whileBuilding: error.whileBuilding,
    registeredElsewhere: error.registeredElsewhere,
    sameType: error.sameType,
    hint:
        'A widget sees only the scopes above it in the widget tree. Wrap the '
        'widgets that need $scopes in CobaltScopeProvider(scope: ..., '
        'child: ...), or let a CobaltScopeWidget own that scope around them.',
  );
}
