import 'package:cobalt/cobalt.dart';

/// The keys [scope] registers itself, in the order a description lists them.
List<CobaltKey> describedKeysOf(CobaltScope scope) =>
    scope.keys.toList()..sort((a, b) => '$a'.compareTo('$b'));

/// What a description says about [key] in [scope]: its kind, the class it
/// builds when that is not the key's own type and its factory says (see
/// `CobaltDescribedFactory`), whether an override stands in for it, and what
/// decorates it, innermost first.
///
/// Shared by `describeGraph` and `describeGraphMermaid`, so the text and the
/// picture of one graph cannot disagree.
List<String> factsOf(CobaltScope scope, CobaltKey key) {
  final info = scope.registrationOf(key);
  return [
    info?.kind.name ?? 'unknown',
    if (info?.implementation case final implementation?
        when implementation != '${key.type}')
      'as $implementation',
    if (scope.overriddenKeys.contains(key)) 'overridden',
    if (info?.decorators case final decorators? when decorators.isNotEmpty)
      'decorated: ${decorators.join(' → ')}',
  ];
}
