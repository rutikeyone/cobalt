import 'package:cobalt_analyzer/src/model/scope_root_class.dart';
import 'package:cobalt_analyzer/src/parser/cobalt_matchers.dart';
import 'package:cobalt_analyzer/src/parser/dart_object_reader.dart';
import 'package:cobalt_analyzer/src/parser/provides_reader.dart';
import 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
import 'package:analyzer/dart/element/element.dart';

class CobaltScopeRootParser {
  const CobaltScopeRootParser();

  bool declares(ClassElement clazz) => scopeRootMatcher.matches(clazz);

  CobaltScopeRootClass parseClass(ClassElement clazz) {
    final annotation = scopeRootMatcher.firstOf(clazz)!;
    return CobaltScopeRootClass(
      type: typeRefOfElement(clazz),
      name: annotation.readString('name') ?? 'root',
      provides: providesOf(annotation, clazz),
    );
  }
}
