import 'package:cobalt_analyzer/src/model/type_ref.dart';
import 'package:cobalt_analyzer/src/parser/cobalt_matchers.dart';
import 'package:cobalt_analyzer/src/parser/parse_error.dart';
import 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';

/// The `scope:` of a `@CobaltInject` or `@CobaltInit`, or null for the root.
CobaltTypeRef? scopeOf(DartObject? annotation, String where, Element element) {
  final scope = annotation?.getField('scope')?.toTypeValue();
  if (scope == null) return null;
  final marker = scope.element;
  if (marker is! ClassElement || !childScopeMatcher.matches(marker)) {
    throw CobaltParseError(
      '$where is registered in scope ${scope.getDisplayString()}, which is not '
      'a @CobaltChildScope marker. Annotate it with @CobaltChildScope(), or '
      'leave scope out to register in the root.',
      element,
    );
  }
  return typeRefOfElement(marker);
}
