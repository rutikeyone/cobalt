import 'package:cobalt/src/key/cobalt_key.dart';
import 'package:cobalt/src/scope/cobalt_registration_kind.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// What a scope knows about one registration, as `CobaltScope.registrationOf`
/// reports it.
///
/// A description, not the registration itself. The registration carries
/// factories and mutable build state, which stay internal so that reading a
/// graph can never change it.
@immutable
final class CobaltRegistrationInfo {
  /// Describes the registration of [key].
  const CobaltRegistrationInfo({
    required this.key,
    required this.kind,
    this.implementation,
    this.decorators = const [],
    this.isOverridden = false,
  });

  /// The key it is registered under.
  final CobaltKey key;

  /// How long what it builds lives, and how it is resolved.
  final CobaltRegistrationKind kind;

  /// The class it builds, when its factory says (see
  /// `CobaltDescribedFactory`); null when it does not.
  ///
  /// The generator's factories always say, which is how a tool can tell
  /// `FakeApiClient` from `LiveApiClient` behind one `ApiClient`.
  final String? implementation;

  /// The decorators that wrap it, in the order they apply, innermost first;
  /// empty when none do.
  ///
  /// Each is named by the `debugLabel` it was added with, or by its type.
  final List<String> decorators;

  /// Whether the scope that owns it registers it from an override rather than
  /// from its own registrations.
  final bool isOverridden;

  static const _strings = ListEquality<String>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CobaltRegistrationInfo &&
          other.key == key &&
          other.kind == kind &&
          other.implementation == implementation &&
          _strings.equals(other.decorators, decorators) &&
          other.isOverridden == isOverridden;

  @override
  int get hashCode => Object.hash(
    key,
    kind,
    implementation,
    _strings.hash(decorators),
    isOverridden,
  );

  @override
  String toString() => [
    '$key: ${kind.name}',
    if (implementation != null) 'implementation: $implementation',
    if (decorators.isNotEmpty) 'decorators: ${decorators.join(', ')}',
    if (isOverridden) 'overridden',
  ].join(', ');
}
