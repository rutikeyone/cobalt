import 'package:cobalt/cobalt.dart';

/// An [CobaltFactory] built from a function.
///
/// Registering a lazy singleton needs a factory object, so a test that only
/// wants to return a stub had to declare a class for it. This is that class,
/// written once.
class FnFactory<T extends Object> implements CobaltFactory<T> {
  /// Creates a factory that calls [build].
  const FnFactory(this.build);

  /// Builds the instance, resolving whatever else it needs.
  final T Function(CobaltResolver resolver) build;

  @override
  T create(CobaltResolver resolver) => build(resolver);
}

/// An [CobaltFactory] that always returns the same value.
///
/// Unlike `registerSingleton`, this keeps the registration lazy — the value is
/// handed out on first resolution, so a test can assert that nothing resolved
/// it at all.
class ValueFactory<T extends Object> implements CobaltFactory<T> {
  /// Creates a factory returning [value].
  const ValueFactory(this.value);

  /// What every resolution returns.
  final T value;

  @override
  T create(CobaltResolver resolver) => value;
}

/// An [CobaltAsyncFactory] built from a function.
class AsyncFnFactory<T extends Object> implements CobaltAsyncFactory<T> {
  /// Creates a factory that calls [build].
  const AsyncFnFactory(this.build);

  /// Builds the instance.
  final Future<T> Function(CobaltResolver resolver) build;

  @override
  Future<T> create(CobaltResolver resolver) => build(resolver);
}

/// An [CobaltParamFactory] built from a function.
///
/// The sibling of [FnFactory] for `registerParamFactory`, which needs its own
/// interface because the argument the container cannot supply is passed in.
class FnParamFactory<T extends Object, P extends Object>
    implements CobaltParamFactory<T, P> {
  /// Creates a factory that calls [build].
  const FnParamFactory(this.build);

  /// Builds the instance from the runtime argument.
  final T Function(CobaltResolver resolver, P param) build;

  @override
  T create(CobaltResolver resolver, P param) => build(resolver, param);
}

/// An [CobaltDecorator] built from a function.
///
/// The sibling of [FnFactory] for `CobaltScope.decorate`, so a test that only
/// wants to wrap something need not declare a class for it.
class FnDecorator<T extends Object> implements CobaltDecorator<T> {
  /// Creates a decorator that calls [wrap].
  const FnDecorator(this.wrap);

  /// Returns what callers receive instead of the inner instance.
  final T Function(T inner, CobaltResolver resolver) wrap;

  @override
  T decorate(T inner, CobaltResolver resolver) => wrap(inner, resolver);
}
