import 'package:cobalt_analyzer/cobalt_analyzer.dart';

/// Names the generated factory class of every declaration in one container.
///
/// A factory is named after what *declares* the registration rather than what
/// it returns, because two modules may legitimately both provide a `Dio`. That
/// leaves one collision the name alone cannot resolve: two libraries in the
/// same package declaring classes of the same name. The build accepts both —
/// a registration key is `import#name`, so they are two distinct keys — and
/// then emits `_ClockFactory` twice, producing a file that does not compile
/// and an error naming the generated symbol instead of either class.
///
/// So a base name more than one declaration claims gets a suffix on **every**
/// claimant, derived from the library it comes from. Two properties matter and
/// both are deliberate:
///
/// - a name nobody contests is left exactly as it was, so adding a second
///   `Clock` never renames anything else in the file;
/// - the suffix is a function of the library alone, so it does not depend on
///   the order declarations were visited in and does not move between builds.
///
/// One instantiation of a generic class is named after its type arguments as
/// well, `_CacheOfNoteFactory` beside `_CacheOfUserFactory`, because every
/// instantiation comes from the same class in the same library and the
/// library alone could not tell them apart. For the same reason a contested
/// instantiation takes its suffix from the whole type rather than from the
/// library.
class CobaltFactoryNames {
  /// Names the factories of [declarations], resolving collisions among them.
  CobaltFactoryNames(
    Iterable<CobaltInjectableClass> declarations, {
    Iterable<CobaltDecoratorClass> decorators = const [],
  }) : _contested = _contestedIn(declarations),
       _contestedDecorators = _twiceIn(decorators.map(_decoratorBaseOf));

  final Set<String> _contested;
  final Set<String> _contestedDecorators;

  /// The class name to emit for [decorator], contested the same way a
  /// factory name is: two decorator classes of one name in different
  /// libraries would otherwise emit one private class twice.
  String ofDecorator(CobaltDecoratorClass decorator) {
    final base = _decoratorBaseOf(decorator);
    if (!_contestedDecorators.contains(base)) return base;
    return '$base\$${_aliasOf(decorator.type.import ?? '')}';
  }

  static String _decoratorBaseOf(CobaltDecoratorClass decorator) =>
      '_${decorator.type.name}Decorator';

  /// The class name to emit for [declaration].
  String of(CobaltInjectableClass declaration) {
    final base = _baseNameOf(declaration);
    if (!_contested.contains(base)) return base;
    return '$base\$${_suffixOf(declaration)}';
  }

  /// The name of the record type holding [declaration]'s call-site values.
  ///
  /// Contested the same way the factory name is, and for the same reason: both
  /// are derived from the class name, so two classes of one name in different
  /// libraries collide in both places at once.
  String argsOf(CobaltInjectableClass declaration) {
    final base = _baseNameOf(declaration);
    final name =
        '\$${_capitalised(_typeTagOf(declaration.type))}'
        '${_capitalised(declaration.name)}Args';
    if (!_contested.contains(base)) return name;
    return '$name\$${_suffixOf(declaration)}';
  }

  static Set<String> _contestedIn(
    Iterable<CobaltInjectableClass> declarations,
  ) => _twiceIn(declarations.map(_baseNameOf));

  static Set<String> _twiceIn(Iterable<String> names) {
    final seen = <String>{};
    final twice = <String>{};
    for (final name in names) {
      if (!seen.add(name)) twice.add(name);
    }
    return twice;
  }

  static String _baseNameOf(CobaltInjectableClass declaration) {
    final suffix = _capitalised(declaration.name);
    final provider = declaration.provider;
    // A module member is named after where it lives, not after what it
    // returns: two modules may legitimately both provide a Dio, and naming
    // both factories after the return type would put two _DioFactory classes
    // in one file.
    if (provider != null) {
      return '_${provider.module.name}${_capitalised(provider.member)}'
          '${suffix}Factory';
    }
    return '_${_typeTagOf(declaration.type)}${suffix}Factory';
  }

  /// [type] as part of an identifier: its name, then its type arguments
  /// after `Of` and joined by `And`, each nullable one marked `Nullable`.
  /// `Pair<String, List<Note?>>` reads `PairOfStringAndListOfNullableNote`.
  static String _typeTagOf(CobaltTypeRef type) {
    final name = _identifierOf(type.name);
    if (type.typeArguments.isEmpty) return name;
    final arguments = type.typeArguments.map(
      (argument) =>
          '${argument.isNullable ? 'Nullable' : ''}'
          '${_capitalised(_typeTagOf(argument))}',
    );
    return '${name}Of${arguments.join('And')}';
  }

  /// [name] with everything an identifier cannot hold dropped, for a type
  /// argument written as a record or a function type.
  static String _identifierOf(String name) {
    if (_identifier.hasMatch(name)) return name;
    return name
        .split(RegExp(r'[^A-Za-z0-9_$]+'))
        .where((part) => part.isNotEmpty)
        .map(_capitalised)
        .join();
  }

  static final _identifier = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$');

  static bool _isInstantiation(CobaltInjectableClass declaration) =>
      declaration.provider == null && declaration.type.typeArguments.isNotEmpty;

  static int _suffixOf(CobaltInjectableClass declaration) => _aliasOf(
    _isInstantiation(declaration)
        ? declaration.type.signature
        : _libraryOf(declaration),
  );

  static String _libraryOf(CobaltInjectableClass declaration) =>
      declaration.provider?.module.import ?? declaration.type.import ?? '';

  /// The same hash the import allocator uses, for the same reason: it depends
  /// on the library and nothing else, so the name is stable across builds.
  static int _aliasOf(String library) => library.hashCode / 1000000 ~/ 1;

  static String _capitalised(String? value) => value == null || value.isEmpty
      ? ''
      : '${value[0].toUpperCase()}${value.substring(1)}';
}
