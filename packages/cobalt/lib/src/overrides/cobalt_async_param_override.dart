import 'package:cobalt/src/factory/cobalt_async_param_factory.dart';
import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/overrides/cobalt_override.dart';
import 'package:cobalt/src/scope/cobalt_scope.dart';

/// Replaces an async parameterized registration of [T] taking a [P].
///
/// Resolved with `getAsyncWithParam<T, P>`, exactly like the registration it
/// replaces.
final class CobaltAsyncParamOverride<T extends Object, P extends Object>
    implements CobaltOverride<T> {
  /// Replaces [T] with [factory].
  const CobaltAsyncParamOverride(this.factory, {this.name});

  /// What builds the replacement.
  final CobaltAsyncParamFactory<T, P> factory;

  /// The name of the registration replaced, if it is named.
  final String? name;

  @override
  CobaltKey get key => CobaltKey(T, name: name);

  @override
  void applyTo(CobaltScope scope) =>
      scope.registerAsyncParamFactory<T, P>(factory, name: name);
}
