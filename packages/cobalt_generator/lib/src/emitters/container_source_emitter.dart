import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_annotations/cobalt_annotations.dart';
import 'package:cobalt_generator/src/emitters/cobalt_factory_names.dart';
import 'package:cobalt_generator/src/emitters/cobalt_references.dart';
import 'package:cobalt_generator/src/emitters/bootstrap_emitter.dart';
import 'package:cobalt_generator/src/emitters/injectable_factory_emitter.dart';
import 'package:cobalt_generator/src/emitters/root_scope_emitter.dart';
import 'package:cobalt_generator/src/emitters/start_function_emitter.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:cobalt_generator/src/hashed_allocator.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

const _header = '// GENERATED CODE - DO NOT MODIFY BY HAND';

class ContainerSourceEmitter {
  const ContainerSourceEmitter();

  static const _factories = InjectableFactoryEmitter();
  static const _rootScope = RootScopeEmitter();
  static const _bootstrap = BootstrapEmitter();
  static const _start = StartFunctionEmitter();

  String emit(CobaltLibraryDeclarations declarations) {
    final injectables = [...declarations.injectables]
      ..sort((a, b) {
        final byKey = _keyOf(a).compareTo(_keyOf(b));
        return byKey != 0 ? byKey : a.type.name.compareTo(b.type.name);
      });

    _assertNoEnvironmentConflicts(injectables);

    final scopeName = _start.resolveName(declarations.scopeRoots);

    _assertNoMissingDependencies(injectables, declarations.scopeRoots);

    _assertDependsOnIsAsync(injectables);

    final lazyKeys = {
      for (final declaration in injectables)
        if (declaration.isLazyAsync) _keyOf(declaration),
    };
    _assertLazyIsAwaited(injectables, lazyKeys);

    final ordered = _withDerivedDependsOn(injectables);
    final names = CobaltFactoryNames(ordered);

    final hasBootstrap = declarations.bootstrapSteps.isNotEmpty;
    final scopeUsesEnvironments = injectables.any(
      (declaration) => declaration.environments.isNotEmpty,
    );
    final bootstrapUsesEnvironments = declarations.bootstrapSteps.any(
      (step) => step.environments.isNotEmpty,
    );

    final library = Library(
      (b) => b
        ..body.addAll([
          for (final declaration in ordered)
            if (declaration.takesCallSiteValues)
              _argsTypedef(declaration, names),
          for (final declaration in ordered)
            _factories.emit(declaration, names, awaited: lazyKeys),
          if (ordered.isNotEmpty)
            _rootScope.emit(
              _ordered(ordered),
              names,
              usesEnvironments: scopeUsesEnvironments,
            ),
          if (hasBootstrap)
            _bootstrap.emit(
              declarations.bootstrapSteps,
              usesEnvironments: bootstrapUsesEnvironments,
            ),
          if (injectables.isNotEmpty) ...[
            _start.emitName(scopeName),
            _start.emitStart(
              hasBootstrap: hasBootstrap,
              scopeUsesEnvironments: scopeUsesEnvironments,
              bootstrapUsesEnvironments: bootstrapUsesEnvironments,
            ),
          ],
        ]),
    );

    final emitted = library.accept(
      DartEmitter(
        allocator: HashedAllocator(),
        orderDirectives: true,
        useNullSafetySyntax: true,
      ),
    );

    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format('$_header\n\n$emitted');
  }

  /// The record a parameterized registration is resolved with.
  ///
  /// Named rather than positional, and named even for a single value: adding
  /// a second one then changes what the call site passes rather than the name
  /// of the type, and the call keeps reading like the constructor it stands
  /// for. It lives here rather than beside the class so that annotating a
  /// parameter does not also require a `part` directive.
  Spec _argsTypedef(
    CobaltInjectableClass declaration,
    CobaltFactoryNames names,
  ) {
    return TypeDef(
      (b) => b
        ..name = names.argsOf(declaration)
        ..definition = RecordType(
          (r) => r
            ..namedFieldTypes.addAll({
              for (final value in declaration.callSiteValues)
                value.field: recordFieldTypeOf(value.type),
            }),
        ),
    );
  }

  List<CobaltInjectableClass> _ordered(
    List<CobaltInjectableClass> injectables,
  ) {
    final byKey = _groupByKey(injectables);

    final levels = layeredTopologicalSort<CobaltInjectableClass>(
      injectables,
      (declaration) => [
        for (final dependency in _dependenciesOf(declaration))
          ...?byKey[dependency.key],
      ],
      labelOf: (declaration) => declaration.label,
    );

    return [for (final level in levels) ...level];
  }

  /// Rejects a graph where something is injected that nothing registers.
  ///
  /// This is the whole point of generating a container rather than resolving
  /// by hand: a dependency nobody supplies is a build failure, not an
  /// `CobaltNotRegisteredError` on the device.
  ///
  /// It runs once per environment, because a registration restricted to one
  /// is absent from the others — a `prod` class may only depend on something
  /// every `prod` build has. The environments considered are the ones the
  /// package declares; [CobaltEnvironment.defaultEnvironment] joins them only
  /// when there are none, since a split graph started without choosing is
  /// deliberately a runtime failure rather than a build one.
  void _assertNoMissingDependencies(
    List<CobaltInjectableClass> injectables,
    List<CobaltScopeRootClass> roots,
  ) {
    final provided = {
      for (final root in roots)
        for (final ref in root.provides) _refKey(ref.type, ref.name),
    };
    final universe = _environmentUniverse(injectables);
    final missing = <String, _MissingDependency>{};

    for (final environment in universe) {
      final active = [
        for (final declaration in injectables)
          if (declaration.environments.isEmpty ||
              declaration.environments.contains(environment))
            declaration,
      ];
      final available = {
        ...provided,
        for (final declaration in active) _keyOf(declaration),
      };

      for (final declaration in active) {
        for (final dependency in _dependenciesOf(declaration)) {
          if (dependency.isOptional) continue;
          if (available.contains(dependency.key)) continue;
          missing
              .putIfAbsent(
                '${declaration.type.name}#${dependency.key}',
                () => _MissingDependency(declaration.label, dependency.label),
              )
              .environments
              .add(environment);
        }
      }
    }

    if (missing.isEmpty) return;
    throw CobaltGenerationError(
      _missingMessage(missing.values.toList(), universe),
    );
  }

  /// Rejects a `dependsOn` naming a registration that is not async.
  ///
  /// `dependsOn` sequences phase 1, so the only thing it can wait for is
  /// another `@CobaltInit`. Naming a plain registration used to generate a
  /// container the runtime would silently ignore that edge in — the
  /// declaration read as an ordering guarantee that was never in force.
  ///
  /// A key nothing registers is not reported here: the completeness check
  /// above already names it, and better. And a key that is async in *some*
  /// environment is left alone — a registration split across builds is not a
  /// mistake, and this check refuses only what is async nowhere.
  void _assertDependsOnIsAsync(List<CobaltInjectableClass> injectables) {
    final registered = {
      for (final declaration in injectables) _keyOf(declaration),
    };
    final asyncKeys = {
      for (final declaration in injectables)
        if (declaration.isAsyncInit && !declaration.isLazyAsync)
          _keyOf(declaration),
    };
    final lazyKeys = {
      for (final declaration in injectables)
        if (declaration.isLazyAsync) _keyOf(declaration),
    };

    final lazy = <String>[];
    final wrong = <String>[];
    for (final declaration in injectables) {
      for (final dependency in declaration.dependsOn) {
        final key = _refKey(dependency, null);
        if (asyncKeys.contains(key)) continue;
        if (lazyKeys.contains(key)) {
          lazy.add('${declaration.label} waits for ${dependency.name}');
        } else if (registered.contains(key)) {
          wrong.add('${declaration.label} waits for ${dependency.name}');
        }
      }
    }

    if (lazy.isNotEmpty) {
      throw CobaltGenerationError(
        'dependsOn cannot wait for a lazy async registration.\n'
        '${lazy.map((line) => '  $line').join('\n')}\n'
        'A lazy registration is built by the first getAsync, not by init(), '
        'so init() has nothing to wait for. Make the waiting class lazy too, '
        'or drop lazy from what it waits for.',
      );
    }
    if (wrong.isEmpty) return;

    throw CobaltGenerationError(
      'dependsOn can only wait for an async registration.\n'
      '${wrong.map((line) => '  $line').join('\n')}\n'
      'Annotate what it waits for with @CobaltInit, or drop the dependsOn: a '
      'registration without an async build has nothing to finish, and the '
      'container would ignore the edge.',
    );
  }

  /// Rejects anything that would have to hold a lazy registration without
  /// awaiting it.
  ///
  /// A lazy async registration exists only once someone awaits `getAsync`, so
  /// the only thing that can take one as a dependency is another lazy
  /// registration, whose factory is itself awaited. A synchronous or eager
  /// dependent would be handed nothing — at runtime that is a
  /// `CobaltLazyAsyncError` on the first resolve, which this makes a build
  /// failure instead. `@injected` fields are filled synchronously, so they
  /// are refused on every class.
  void _assertLazyIsAwaited(
    List<CobaltInjectableClass> injectables,
    Set<String> lazyKeys,
  ) {
    if (lazyKeys.isEmpty) return;

    final wrong = <String>[];
    for (final declaration in injectables) {
      for (final parameter in declaration.constructorParameters) {
        if (parameter.isParam || declaration.isLazyAsync) continue;
        if (!lazyKeys.contains(_refKey(parameter.type, parameter.name))) {
          continue;
        }
        wrong.add('${declaration.label} injects ${_display(parameter.type)}');
      }
      for (final property in declaration.properties) {
        if (!lazyKeys.contains(_refKey(property.type, property.name))) {
          continue;
        }
        wrong.add(
          '${declaration.label}.${property.field} injects '
          '${_display(property.type)}',
        );
      }
    }
    if (wrong.isEmpty) return;

    throw CobaltGenerationError(
      'A lazy async registration can only be injected into another lazy one.\n'
      '${wrong.map((line) => '  $line').join('\n')}\n'
      'It is built by the first getAsync, so there is nothing to hand over '
      'synchronously. Make the dependent @CobaltInit(lazy: true) — its factory '
      'then awaits it — or resolve it with getAsync where it is needed.',
    );
  }

  /// Fills in async ordering for module members.
  ///
  /// An `@CobaltInit` class states `dependsOn` by hand. A module member has
  /// nowhere to write it, and does not need to: the whole package is in hand
  /// here, so which of its parameters are themselves async is a fact the
  /// generator can read off the graph rather than ask for. What it emits is
  /// exactly what a hand-written registration would say.
  ///
  /// Named async dependencies are left out, because `dependsOn` in the IR
  /// carries a type and no qualifier.
  List<CobaltInjectableClass> _withDerivedDependsOn(
    List<CobaltInjectableClass> injectables,
  ) {
    final asyncKeys = {
      for (final declaration in injectables)
        if (declaration.isAsyncInit && !declaration.isLazyAsync)
          _keyOf(declaration),
    };

    return [
      for (final declaration in injectables)
        if (declaration.provider == null ||
            !declaration.isAsyncInit ||
            declaration.isLazyAsync ||
            declaration.dependsOn.isNotEmpty)
          declaration
        else
          declaration.withDependsOn([
            for (final parameter in declaration.constructorParameters)
              if (parameter.name == null &&
                  asyncKeys.contains(_refKey(parameter.type, null)))
                parameter.type,
          ]),
    ];
  }

  static List<String> _environmentUniverse(
    List<CobaltInjectableClass> injectables,
  ) {
    final declared = {
      for (final declaration in injectables) ...declaration.environments,
    };
    if (declared.isEmpty) return [CobaltEnvironment.defaultEnvironment.name];
    return declared.toList()..sort();
  }

  static String _missingMessage(
    List<_MissingDependency> missing,
    List<String> universe,
  ) {
    if (missing.length == 1) {
      final only = missing.single;
      return '${only.dependent} requires ${only.label}'
          '${_whereMissing(only, universe)}, which nothing registers. '
          'Annotate the class that provides it with @CobaltInject, add an '
          '@CobaltModule member returning it when the type is not yours, or '
          'name it in @CobaltScopeRoot(provides: [...]) when something outside '
          'the generated container registers it.';
    }
    final lines = [
      for (final entry in missing)
        '  ${entry.dependent} requires ${entry.label}'
            '${_whereMissing(entry, universe)}',
    ].join('\n');
    return 'The graph is missing ${missing.length} registrations.\n$lines\n'
        'Annotate the classes that provide them with @CobaltInject, add '
        '@CobaltModule members returning them when the types are not yours, or '
        'name them in @CobaltScopeRoot(provides: [...]) when something outside '
        'the generated container registers them.';
  }

  static String _whereMissing(
    _MissingDependency entry,
    List<String> universe,
  ) => entry.environments.length == universe.length
      ? ''
      : ' in ${(entry.environments.toList()..sort()).join(', ')}';

  /// Rejects a graph where two registrations of the same type could be active
  /// at once.
  ///
  /// Without environments a duplicate is always a mistake. With them it is a
  /// mistake only when the environments overlap — or when one side names none,
  /// since an unrestricted registration is present in every environment.
  void _assertNoEnvironmentConflicts(List<CobaltInjectableClass> injectables) {
    for (final group in _groupByKey(injectables).values) {
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          final first = group[i];
          final second = group[j];
          if (!_canCoexist(first.environments, second.environments)) continue;
          throw CobaltGenerationError(_conflictMessage(first, second));
        }
      }
    }
  }

  static String _conflictMessage(
    CobaltInjectableClass first,
    CobaltInjectableClass second,
  ) {
    final exposed = first.exposedType.name;
    final named = first.name == null ? '' : " named '${first.name}'";
    final where = _overlapDescription(first.environments, second.environments);
    return '${first.label} and ${second.label} both register '
        '$exposed$named$where. Give them environments that do not overlap, '
        'or expose one of them as a different type.';
  }

  static String _overlapDescription(Set<String> first, Set<String> second) {
    if (first.isEmpty && second.isEmpty) return '';
    if (first.isEmpty || second.isEmpty) {
      final restricted = first.isEmpty ? second : first;
      final names = (restricted.toList()..sort()).join(', ');
      return ', and one of them names no environment, so both are active in '
          '$names';
    }
    final shared = (first.intersection(second).toList()..sort()).join(', ');
    return ' in $shared';
  }

  static bool _canCoexist(Set<String> first, Set<String> second) =>
      first.isEmpty || second.isEmpty || first.intersection(second).isNotEmpty;

  static Map<String, List<CobaltInjectableClass>> _groupByKey(
    List<CobaltInjectableClass> injectables,
  ) {
    final byKey = <String, List<CobaltInjectableClass>>{};
    for (final declaration in injectables) {
      byKey.putIfAbsent(_keyOf(declaration), () => []).add(declaration);
    }
    return byKey;
  }

  /// The graph edges of one declaration.
  ///
  /// An `@CobaltParam` is skipped here rather than in the completeness check,
  /// which is the opposite of how an optional dependency is handled: an
  /// optional one is still an ordering edge when the type happens to be
  /// registered, while a call-site value is no edge at all — nothing registers
  /// an `int`, and demanding one would fail every parameterized graph.
  Iterable<_Dependency> _dependenciesOf(CobaltInjectableClass declaration) => [
    for (final parameter in declaration.constructorParameters)
      if (!parameter.isParam) _dependency(parameter.type, parameter.name),
    for (final property in declaration.properties)
      _dependency(property.type, property.name),
    for (final dependency in declaration.dependsOn)
      _dependency(dependency, null, isOptional: false),
  ];

  static _Dependency _dependency(
    CobaltTypeRef type,
    String? name, {
    bool isOptional = true,
  }) => (
    key: _refKey(type, name),
    label: name == null ? _display(type) : "${_display(type)} named '$name'",
    isOptional: isOptional && type.isNullable,
  );

  /// The type as a reader recognises it, without nullability.
  ///
  /// A `Foo?` dependency still reads the `Foo` *key* — nullability marks the
  /// dependency optional, it does not make a second registration — so naming
  /// `Foo?` here would name something that never exists as a key.
  static String _display(CobaltTypeRef type) {
    if (type.typeArguments.isEmpty) return type.name;
    final arguments = type.typeArguments.map(_display).join(', ');
    return '${type.name}<$arguments>';
  }

  static String _keyOf(CobaltInjectableClass declaration) =>
      _refKey(declaration.exposedType, declaration.name);

  static String _refKey(CobaltTypeRef type, String? name) =>
      registrationKey(type, name);
}

typedef _Dependency = ({String key, String label, bool isOptional});

class _MissingDependency {
  _MissingDependency(this.dependent, this.label);

  final String dependent;
  final String label;
  final Set<String> environments = {};
}
