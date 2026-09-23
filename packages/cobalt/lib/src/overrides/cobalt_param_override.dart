import 'package:cobalt/src/factory/cobalt_param_factory.dart';
import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/overrides/cobalt_override.dart';
import 'package:cobalt/src/scope/cobalt_scope.dart';

/// Replaces a parameterized registration of [T] taking a [P].
///
/// The parameterized counterpart of [CobaltOverride]: resolved with
/// `getWithParam<T, P>`, exactly like the registration it replaces.
final class CobaltParamOverride<T extends Object, P extends Object>
    implements CobaltOverride<T> {
  /// Replaces [T] with [factory].
  const CobaltParamOverride(this.factory, {this.name});

  /// What builds the replacement.
  final CobaltParamFactory<T, P> factory;

  /// The name of the registration replaced, if it is named.
  final String? name;

  @override
  CobaltKey get key => CobaltKey(T, name: name);

  @override
  void applyTo(CobaltScope scope) =>
      scope.registerParamFactory<T, P>(factory, name: name);
}
