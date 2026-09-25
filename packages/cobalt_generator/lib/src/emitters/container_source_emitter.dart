import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_annotations/cobalt_annotations.dart';
import 'package:cobalt_generator/src/emitters/cobalt_factory_names.dart';
import 'package:cobalt_generator/src/emitters/cobalt_references.dart';
import 'package:cobalt_generator/src/emitters/bootstrap_emitter.dart';
import 'package:cobalt_generator/src/emitters/decorator_emitter.dart';
import 'package:cobalt_generator/src/emitters/injectable_factory_emitter.dart';
import 'package:cobalt_generator/src/emitters/root_scope_emitter.dart';
import 'package:cobalt_generator/src/emitters/start_function_emitter.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:cobalt_generator/src/hashed_allocator.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';

const _header = '// GENERATED CODE - DO NOT MODIFY BY HAND';

class ContainerSourceEmitter {
  const ContainerSourceEmitter();

  static const _factories = InjectableFactoryEmitter();
  static const _rootScope = RootScopeEmitter();
  static const _bootstrap = BootstrapEmitter();
  static const _start = StartFunctionEmitter();
  static const _decorators = DecoratorEmitter();

  String emit(CobaltLibraryDeclarations declarations) {
    final injectables = [...declarations.injectables]
      ..sort((a, b) {
        final byKey = _keyOf(a).compareTo(_keyOf(b));
        return byKey != 0 ? byKey : a.type.name.compareTo(b.type.name);
      });

    final decorators = [...declarations.decorators]
      ..sort((a, b) {
        final byTarget = _targetOf(a).compareTo(_targetOf(b));
        if (byTarget != 0) return byTarget;
        final byOrder = (a.order ?? 0).compareTo(b.order ?? 0);
        return byOrder != 0 ? byOrder : a.type.name.compareTo(b.type.name);
      });

    _assertNoEnvironmentConflicts(injectables);

    final scopeName = _start.resolveName(declarations.scopeRoots);

    _assertDecoratorsHaveTargets(
      injectables,
      decorators,
      declarations.scopeRoots,
    );

    _assertNoMissingDependencies(
      injectables,
      declarations.scopeRoots,
      decorators,
    );

    _assertDecoratorOrder(decorators);

    _assertDependsOnIsAsync(injectables);

    final lazyKeys = {
      for (final declaration in injectables)
        if (declaration.isLazyAsync) _keyOf(declaration),
    };
    _assertLazyIsAwaited(injectables, lazyKeys, decorators);

    final ordered = _withDerivedDependsOn(injectables, decorators);
    final names = CobaltFactoryNames(ordered, decorators: decorators);

    final hasBootstrap = declarations.bootstrapSteps.isNotEmpty;
    final scopeUsesEnvironments =
        injectables.any((declaration) => declaration.environments.isNotEmpty) ||
        decorators.any((decorator) => decorator.environments.isNotEmpty);
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
          for (final decorator in decorators)
            _decorators.emit(decorator, names),
          if (ordered.isNotEmpty || decorators.isNotEmpty)
            _rootScope.emit(
              _ordered(ordered, decorators),
              names,
              usesEnvironments: scopeUsesEnvironments,
              decorators: decorators,
            ),
          if (hasBootstrap)
            _bootstrap.emit(
              declarations.bootstrapSteps,
              usesEnvironments: bootstrapUsesEnvironments,
            ),
          if (injectables.isNotEmpty || decorators.isNotEmpty) ...[
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
      languageVersion: _formattedAs,
    ).format('$_header\n\n$emitted');
  }

  static final _formattedAs = Version(3, 10, 0);

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

  /// Orders registrations so each comes after what it depends on.
  ///
  /// A decorator's dependencies count as its target's: the decorator runs
  /// whenever the target is handed out, so what it resolves has to be there
  /// by then, and a decorator that needs something depending on its own
  /// target is a cycle like any other.
  List<CobaltInjectableClass> _ordered(
    List<CobaltInjectableClass> injectables,
    List<CobaltDecoratorClass> decorators,
  ) {
    final byKey = _groupByKey(injectables);
    final decoratorsByTarget = _decoratorsByTarget(decorators);

    final levels = layeredTopologicalSort<CobaltInjectableClass>(
      injectables,
      (declaration) => [
        for (final dependency in _dependenciesOf(declaration))
          ...?byKey[dependency.key],
        for (final decorator
            in decoratorsByTarget[_keyOf(declaration)] ??
                const <CobaltDecoratorClass>[])
          for (final dependency in decorator.dependencies)
            ...?byKey[keyOfDependency(dependency)],
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
    List<CobaltDecoratorClass> decorators,
  ) {
    final provided = _providedKeys(roots);
    final universe = _environmentUniverse(injectables, decorators);
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

      for (final decorator in decorators) {
        if (!_activeIn(decorator.environments, environment)) continue;
        for (final parameter in decorator.dependencies) {
          final dependency = _dependency(parameter.type, parameter.name);
          if (dependency.isOptional) continue;
          if (available.contains(dependency.key)) continue;
          missing
              .putIfAbsent(
                '${decorator.type.name}#${dependency.key}',
                () => _MissingDependency(decorator.type.name, dependency.label),
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

  /// Rejects a decorator of something nothing registers.
  ///
  /// At runtime this is the owner check at the end of `runBuilder`; here it
  /// becomes a build failure, checked per environment for the same reason the
  /// completeness check is. A key named in `provides` is trusted: whatever
  /// registers it by hand registers it in the same scope.
  void _assertDecoratorsHaveTargets(
    List<CobaltInjectableClass> injectables,
    List<CobaltDecoratorClass> decorators,
    List<CobaltScopeRootClass> roots,
  ) {
    if (decorators.isEmpty) return;
    final provided = _providedKeys(roots);
    final universe = _environmentUniverse(injectables, decorators);
    final missing = <CobaltDecoratorClass, Set<String>>{};

    for (final environment in universe) {
      final available = {
        ...provided,
        for (final declaration in injectables)
          if (_activeIn(declaration.environments, environment))
            _keyOf(declaration),
      };
      for (final decorator in decorators) {
        if (!_activeIn(decorator.environments, environment)) continue;
        if (available.contains(_targetOf(decorator))) continue;
        missing.putIfAbsent(decorator, () => {}).add(environment);
      }
    }
    if (missing.isEmpty) return;

    final lines = [
      for (final MapEntry(key: decorator, value: environments)
          in missing.entries)
        '  ${decorator.type.name} decorates ${_targetLabel(decorator)}'
            '${environments.length == universe.length ? '' : ' in ${(environments.toList()..sort()).join(', ')}'}',
    ].join('\n');
    throw CobaltGenerationError(
      'A decorator wraps a registration nothing makes.\n$lines\n'
      'Register what it decorates, restrict the decorator to the environments '
      'that have it, or name it in @CobaltScopeRoot(provides: [...]) when '
      'something outside the generated container registers it.',
    );
  }

  /// Rejects two decorators of one registration that do not say which wraps
  /// which.
  ///
  /// The order decides behaviour — a retry outside a cache is not a cache
  /// outside a retry — and the order classes happen to be read in is no
  /// order at all. Decorators whose environments never meet do not compete.
  void _assertDecoratorOrder(List<CobaltDecoratorClass> decorators) {
    for (final group in _decoratorsByTarget(decorators).values) {
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          final first = group[i];
          final second = group[j];
          if (!_canCoexist(first.environments, second.environments)) continue;
          if (first.order == null || second.order == null) {
            throw CobaltGenerationError(
              '${first.type.name} and ${second.type.name} both decorate '
              '${_targetLabel(first)} and do not say which wraps which. Give '
              'each an order: the lower one is applied first and ends up '
              'innermost.',
            );
          }
          if (first.order == second.order) {
            throw CobaltGenerationError(
              '${first.type.name} and ${second.type.name} both decorate '
              '${_targetLabel(first)} with order ${first.order}. Give them '
              'different orders: the lower one is applied first and ends up '
              'innermost.',
            );
          }
        }
      }
    }
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
    List<CobaltDecoratorClass> decorators,
  ) {
    if (lazyKeys.isEmpty) return;

    final decorating = [
      for (final decorator in decorators)
        for (final parameter in decorator.dependencies)
          if (lazyKeys.contains(keyOfDependency(parameter)))
            '${decorator.type.name} injects ${_display(parameter.type)}',
    ];
    if (decorating.isNotEmpty) {
      throw CobaltGenerationError(
        'A decorator cannot take a lazy async registration.\n'
        '${decorating.map((line) => '  $line').join('\n')}\n'
        'A decorator is applied synchronously, when the instance it wraps is '
        'handed out, so there is no getAsync to await. Resolve it with '
        'getAsync inside the decorated call instead, or drop lazy from it.',
      );
    }

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
  ///
  /// An eager async registration also waits for the async dependencies of
  /// every decorator it reaches while it is built — through what it injects,
  /// and through the synchronous registrations those inject in turn. Handing
  /// out a decorated instance runs the decorator, so what the decorator
  /// resolves has to be finished by then. The wait sits on the consumer, not
  /// on the decorated registration: an override replaces that registration
  /// and would take the wait with it. Only a dependency present in every
  /// environment the consumer is gets added, since `dependsOn` on a key the
  /// build lacks is an error at runtime.
  List<CobaltInjectableClass> _withDerivedDependsOn(
    List<CobaltInjectableClass> injectables,
    List<CobaltDecoratorClass> decorators,
  ) {
    final asyncKeys = {
      for (final declaration in injectables)
        if (declaration.isAsyncInit && !declaration.isLazyAsync)
          _keyOf(declaration),
    };
    final decoratorsByTarget = _decoratorsByTarget(decorators);
    final byKey = _groupByKey(injectables);
    final universe = _environmentUniverse(injectables, decorators);
    Set<String> presentIn(Set<String> environments) =>
        environments.isEmpty ? universe.toSet() : environments;
    final asyncPresence = <String, Set<String>>{};
    for (final declaration in injectables) {
      if (!declaration.isAsyncInit || declaration.isLazyAsync) continue;
      asyncPresence
          .putIfAbsent(_keyOf(declaration), () => {})
          .addAll(presentIn(declaration.environments));
    }

    Iterable<String> injectedKeys(CobaltInjectableClass declaration) => [
      for (final parameter in declaration.constructorParameters)
        if (!parameter.isParam) keyOfDependency(parameter),
      for (final property in declaration.properties) keyOfDependency(property),
    ];

    Set<String> reachedWhileBuilding(CobaltInjectableClass declaration) {
      final reached = <String>{};
      final pending = [...injectedKeys(declaration)];
      while (pending.isNotEmpty) {
        final key = pending.removeLast();
        if (!reached.add(key)) continue;
        for (final provider in byKey[key] ?? const <CobaltInjectableClass>[]) {
          if (provider.isAsyncInit) continue;
          pending.addAll(injectedKeys(provider));
        }
      }
      return reached;
    }

    List<CobaltTypeRef> fromDecorators(CobaltInjectableClass declaration) {
      if (decorators.isEmpty) return const [];
      final needed = presentIn(declaration.environments);
      final own = _keyOf(declaration);
      return [
        for (final key in reachedWhileBuilding(declaration))
          for (final decorator
              in decoratorsByTarget[key] ?? const <CobaltDecoratorClass>[])
            for (final parameter in decorator.dependencies)
              if (parameter.name == null &&
                  _refKey(parameter.type, null) != own &&
                  (asyncPresence[_refKey(parameter.type, null)]?.containsAll(
                        needed,
                      ) ??
                      false))
                parameter.type,
      ];
    }

    return [
      for (final declaration in injectables)
        if (!declaration.isAsyncInit || declaration.isLazyAsync)
          declaration
        else
          _withExtraDependsOn(declaration, [
            if (declaration.provider != null && declaration.dependsOn.isEmpty)
              for (final parameter in declaration.constructorParameters)
                if (parameter.name == null &&
                    asyncKeys.contains(_refKey(parameter.type, null)))
                  parameter.type,
            ...fromDecorators(declaration),
          ]),
    ];
  }

  static CobaltInjectableClass _withExtraDependsOn(
    CobaltInjectableClass declaration,
    List<CobaltTypeRef> extra,
  ) {
    final merged = [...declaration.dependsOn];
    for (final type in extra) {
      if (merged.any((existing) => existing.signature == type.signature)) {
        continue;
      }
      merged.add(type);
    }
    if (merged.length == declaration.dependsOn.length) return declaration;
    return declaration.withDependsOn(merged);
  }

  static Map<String, List<CobaltDecoratorClass>> _decoratorsByTarget(
    List<CobaltDecoratorClass> decorators,
  ) {
    final byTarget = <String, List<CobaltDecoratorClass>>{};
    for (final decorator in decorators) {
      byTarget.putIfAbsent(_targetOf(decorator), () => []).add(decorator);
    }
    return byTarget;
  }

  static Set<String> _providedKeys(List<CobaltScopeRootClass> roots) => {
    for (final root in roots)
      for (final ref in root.provides) _refKey(ref.type, ref.name),
  };

  static bool _activeIn(Set<String> environments, String environment) =>
      environments.isEmpty || environments.contains(environment);

  static String _targetOf(CobaltDecoratorClass decorator) =>
      _refKey(decorator.target, decorator.name);

  static String _targetLabel(CobaltDecoratorClass decorator) {
    final name = decorator.name;
    final target = _display(decorator.target);
    return name == null ? target : "$target named '$name'";
  }

  static List<String> _environmentUniverse(
    List<CobaltInjectableClass> injectables, [
    List<CobaltDecoratorClass> decorators = const [],
  ]) {
    final declared = {
      for (final declaration in injectables) ...declaration.environments,
      for (final decorator in decorators) ...decorator.environments,
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
