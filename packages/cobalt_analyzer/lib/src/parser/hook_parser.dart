import 'package:cobalt_analyzer/src/model/hook_class.dart';
import 'package:cobalt_analyzer/src/parser/cobalt_matchers.dart';
import 'package:cobalt_analyzer/src/parser/dart_object_reader.dart';
import 'package:cobalt_analyzer/src/parser/environment_reader.dart';
import 'package:cobalt_analyzer/src/parser/parse_error.dart';
import 'package:cobalt_analyzer/src/parser/type_ref_resolver.dart';
import 'package:analyzer/dart/element/element.dart';

/// Reads an `@CobaltHookAll` class into the hook the root scope adds.
class CobaltHookParser {
  const CobaltHookParser();

  bool declares(ClassElement clazz) => hookAllMatcher.matches(clazz);

  CobaltHookClass parseClass(ClassElement clazz) {
    final annotation = hookAllMatcher.firstOf(clazz)!;

    if (injectMatcher.matches(clazz) ||
        initMatcher.matches(clazz) ||
        moduleMatcher.matches(clazz) ||
        decoratesMatcher.matches(clazz)) {
      throw CobaltParseError(
        '${clazz.displayName} is both a hook and a registration or decorator. '
        'A hook is added to the scope, not built from it — drop the other '
        'annotation, or split the class.',
        clazz,
      );
    }
    if (clazz.isAbstract) {
      throw CobaltParseError(
        '${clazz.displayName} is abstract and cannot be constructed.',
        clazz,
      );
    }
    if (clazz.typeParameters.isNotEmpty) {
      throw CobaltParseError(
        '${clazz.displayName} declares type parameters, so there is no single '
        'type for the scope to run it on.',
        clazz,
      );
    }

    final hooks = [
      for (final supertype in clazz.allSupertypes)
        if (supertype.element.displayName == 'CobaltHook' &&
            (supertype.element.library.uri.toString()).startsWith(
              'package:cobalt/',
            ))
          supertype,
    ];
    if (hooks.length != 1 || hooks.single.typeArguments.length != 1) {
      throw CobaltParseError(
        '${clazz.displayName} is annotated with @CobaltHookAll but does not '
        'implement CobaltHook<T> for one T — which says what it runs on.',
        clazz,
      );
    }

    final constructor = clazz.constructors
        .where((c) => c.isPublic && !c.isFactory)
        .firstOrNull;
    if (constructor == null) {
      throw CobaltParseError(
        '${clazz.displayName} has no public generative constructor.',
        clazz,
      );
    }
    if (constructor.formalParameters.any((p) => p.isRequired)) {
      throw CobaltParseError(
        '${clazz.displayName} must have a constructor without required '
        'parameters. A hook is added before anything is built, so nothing can '
        'be injected into it; resolve what it needs from the resolver its '
        'onBuilt receives.',
        clazz,
      );
    }

    return CobaltHookClass(
      type: typeRefOfElement(clazz),
      target: typeRefOf(hooks.single.typeArguments.single),
      order: annotation.readInt('order') ?? 0,
      environments: environmentsOf(clazz),
    );
  }
}
