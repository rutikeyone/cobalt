import 'dart:async';

import 'package:cobalt/src/factory/cobalt_factory.dart';
import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/scope/cobalt_scope.dart';

/// Replaces the registration of [T] in the scope it is handed to.
///
/// An override is registered when the scope is created, before anything else,
/// and the real registration of the same key is then skipped rather than
/// rejected as a duplicate. Because it lives in the scope that owns the key,
/// every factory in that scope resolves the replacement — which is what a
/// registration shadowed from a child scope cannot do, since a factory is
/// called with the scope that owns *its* registration.
///
/// ```dart
/// final scope = await CobaltApplication.start(
///   root: const AppScope(),
///   overrides: [
///     CobaltOverride<GreetingStore>.value(const InMemoryGreetingStore()),
///   ],
/// );
/// ```
///
/// Name the type argument. Inside an `overrides:` list Dart infers it from the
/// list as `Object`, which the scope refuses as soon as it is created. Written
/// on its own, `CobaltOverride.value(FakeClock())` infers `FakeClock`, which
/// nothing registers, instead of `Clock` — a scope built through `runBuilder`
/// reports that one once the builder returns. Both are `CobaltOverrideError`.
abstract interface class CobaltOverride<T extends Object> {
  /// Replaces [T] with an already-built [value].
  ///
  /// The scope owns [value] and disposes it like any registered singleton;
  /// [dispose] closes one that implements neither `Disposable` nor
  /// `AsyncDisposable`. This is also the way to replace an async registration,
  /// eager or lazy: build the double first and hand it over.
  const factory CobaltOverride.value(
    T value, {
    String? name,
    FutureOr<void> Function(T instance)? dispose,
  }) = _ValueOverride<T>;

  /// Replaces [T] with a lazy singleton built by [factory] on first use.
  const factory CobaltOverride.lazy(
    CobaltFactory<T> factory, {
    String? name,
    FutureOr<void> Function(T instance)? dispose,
  }) = _LazyOverride<T>;

  /// Replaces [T] with a factory that builds a new instance on every
  /// resolution.
  const factory CobaltOverride.transient(
    CobaltFactory<T> factory, {
    String? name,
  }) = _TransientOverride<T>;

  /// The key this override replaces.
  CobaltKey get key;

  /// Registers the replacement in [scope].
  ///
  /// The scope calls this while it is being created. Calling it anywhere else
  /// is an ordinary registration, with nothing replaced.
  void applyTo(CobaltScope scope);
}

final class _ValueOverride<T extends Object> implements CobaltOverride<T> {
  const _ValueOverride(this.value, {this.name, this.dispose});

  final T value;
  final String? name;
  final FutureOr<void> Function(T instance)? dispose;

  @override
  CobaltKey get key => CobaltKey(T, name: name);

  @override
  void applyTo(CobaltScope scope) =>
      scope.registerSingleton<T>(value, name: name, dispose: dispose);
}

final class _LazyOverride<T extends Object> implements CobaltOverride<T> {
  const _LazyOverride(this.factory, {this.name, this.dispose});

  final CobaltFactory<T> factory;
  final String? name;
  final FutureOr<void> Function(T instance)? dispose;

  @override
  CobaltKey get key => CobaltKey(T, name: name);

  @override
  void applyTo(CobaltScope scope) =>
      scope.registerLazySingleton<T>(factory, name: name, dispose: dispose);
}

final class _TransientOverride<T extends Object> implements CobaltOverride<T> {
  const _TransientOverride(this.factory, {this.name});

  final CobaltFactory<T> factory;
  final String? name;

  @override
  CobaltKey get key => CobaltKey(T, name: name);

  @override
  void applyTo(CobaltScope scope) =>
      scope.registerFactory<T>(factory, name: name);
}
