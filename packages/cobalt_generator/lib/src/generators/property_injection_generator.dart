import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/emitters/injection_mixin_emitter.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// Emits the `_$ClassName` mixin that fills `@injected` fields.
///
/// Runs as a shared part builder, so the mixin lands in the same library as
/// the class and can therefore assign private fields. Classes without
/// `@injected` fields produce nothing.
///
/// A decorator class counts too: `@CobaltDecorates` classes are read by
/// [CobaltDecoratorParser], and the generated decorator calls `onInject` on
/// what it builds.
///
/// Which registrations count is decided by [CobaltInjectableParser.declares],
/// the same reading the container uses, and that is the point: `@CobaltInit` makes
/// a class injectable too, so a class annotated with it alone used to be
/// registered by the container and left without a mixin. Its fields were never
/// assigned and it failed with a `LateInitializationError` at first use, while
/// the lint told you to mix in something the generator was never going to
/// write.
class PropertyInjectionGenerator implements Generator {
  /// Creates the generator.
  const PropertyInjectionGenerator();

  static const _parser = CobaltInjectableParser();
  static const _decorators = CobaltDecoratorParser();
  static const _emitter = InjectionMixinEmitter();

  @override
  String? generate(LibraryReader library, BuildStep buildStep) {
    final mixins = <String>[];

    for (final clazz in library.element.classes) {
      try {
        if (_parser.declares(clazz)) {
          final parsed = _parser.parseClass(clazz).first;
          if (parsed.hasPropertyInjection) mixins.add(_emitter.emit(parsed));
        } else if (_decorators.declares(clazz)) {
          final parsed = _decorators.parseClass(clazz);
          if (parsed.hasPropertyInjection) {
            mixins.add(_emitter.emitFor(parsed.type, parsed.injectedFields));
          }
        }
      } on CobaltParseError catch (error) {
        throw InvalidGenerationSourceError(
          error.message,
          element: error.element,
        );
      }
    }

    if (mixins.isEmpty) return null;
    return mixins.join('\n\n');
  }

  /// Names the banner source_gen writes above the output.
  ///
  /// `GeneratorForAnnotation` prints this for free; a plain [Generator] would
  /// otherwise put `Instance of '...'` into every generated file.
  @override
  String toString() => 'PropertyInjectionGenerator';
}
