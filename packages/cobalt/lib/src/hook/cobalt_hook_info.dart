import 'package:meta/meta.dart';

/// A hook added with `CobaltScope.hookAll`, as `CobaltScope.hooks` reports
/// it.
///
/// A description, not the hook itself, so reading a scope cannot run one.
@immutable
final class CobaltHookInfo {
  /// Describes a hook named [label] that runs on every [type].
  const CobaltHookInfo({required this.label, required this.type});

  /// The `debugLabel` it was added with, or its type.
  final String label;

  /// What it runs on: the type argument it was added with.
  final Type type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CobaltHookInfo && other.label == label && other.type == type;

  @override
  int get hashCode => Object.hash(label, type);

  @override
  String toString() => '$label on $type';
}
