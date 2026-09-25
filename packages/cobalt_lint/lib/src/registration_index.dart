import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/class_members.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/file_system/file_system.dart';

/// What the package registers, and what each registration asks for.
///
/// The generator answers both questions from a fully resolved, whole-package
/// IR. A rule cannot: the analysis server hands it one library at a time, and
/// the only synchronous view of the others is their parsed source. So this
/// index is built from syntax, and is deliberately coarser than
/// `CobaltTypeRef.signature` in one direction only.
///
/// It holds bare type names — no library, no type arguments, no `@Named`
/// qualifier. Every one of those omissions makes [contains] match *more*, so
/// the rule built on it stays silent in cases the build still rejects. Missing
/// a report is acceptable; inventing one from an editor that cannot see the
/// whole graph is not. The build remains the authority.
///
/// [cycle] needs the opposite care. There a coarser name makes the graph
/// *denser*, and a dense graph can grow a loop that no real one has — so a
/// name two declarations in the package both claim is dropped from the graph
/// entirely rather than fused. See [ambiguous].
class CobaltRegistrationIndex {
  const CobaltRegistrationIndex(
    this.names,
    this.edges,
    this.ambiguous,
    this.cycle,
    this.lazy,
  );

  /// Every type name something in the package registers.
  final Set<String> names;

  /// What each registration asks for, keyed by the name it registers.
  ///
  /// Nullable dependencies are edges like any other: the generator skips them
  /// only when checking completeness, never when ordering, because an optional
  /// dependency that *is* registered still has to be built first.
  final Map<String, Set<String>> edges;

  /// Names claimed by more than one declaration, excluded from [edges].
  ///
  /// Two classes called `Clock` in different libraries are two types the build
  /// keeps apart. Merging them by name would hand one of them the other's
  /// dependencies, which is how a graph with no loop grows one.
  ///
  /// Both of them count, registered or not. An unregistered `Clock` is still
  /// something a constructor can take, and from syntax alone an edge naming
  /// `Clock` could mean either — so a name two declarations claim is dropped
  /// even when only one of them is registered. Missing a real loop is the
  /// direction this index is allowed to fail in; reporting one that is not
  /// there is not.
  ///
  /// A same-named type in another *package* stays invisible, and the false
  /// loop with it. Nothing syntactic can see that far.
  final Set<String> ambiguous;

  /// One cycle in the graph, or null when there is none.
  ///
  /// One, not all: `layeredTopologicalSort` reports the first loop it finds,
  /// and the generator shows the same one for the same graph. Reporting a
  /// different set than the build would make the two disagree about a question
  /// they answer identically.
  final List<String>? cycle;

  /// Names registered lazily, built by the first `getAsync` rather than by
  /// `init()`.
  ///
  /// A name in [ambiguous] is left out: from syntax alone it could be the
  /// other declaration, and a rule built on this set must not report a class
  /// for injecting something that may not be lazy at all.
  final Set<String> lazy;

  bool contains(String typeName) => names.contains(typeName);

  /// Reads [files], or returns null when any of them will not parse.
  ///
  /// Null rather than a partial index on purpose: a file that was skipped is a
  /// file whose registrations are missing, and the rules would then report
  /// them as unregistered, or miss the half of a loop that lived there.
  /// Silence is the only safe answer to an incomplete read.
  static CobaltRegistrationIndex? read(
    Iterable<String> files,
    AnalysisSession session,
  ) {
    final builder = _IndexBuilder();
    for (final path in files) {
      final parsed = session.getParsedUnit(path);
      if (parsed is! ParsedUnitResult || parsed.diagnostics.isNotEmpty) {
        return null;
      }
      builder.collect(parsed.unit);
    }
    return builder.build();
  }
}

/// Collects one package's registrations and edges as it walks parsed units.
class _IndexBuilder {
  final names = <String>{};
  final edges = <String, Set<String>>{};
  final ambiguous = <String>{};
  final lazy = <String>{};

  /// How many declarations in the package claim each bare name.
  ///
  /// Registered or not: an unregistered class is still something a dependency
  /// can name, and the index cannot tell the two apart from syntax alone.
  final _claims = <String, int>{};

  CobaltRegistrationIndex build() {
    // A name more than one declaration claims cannot be a node: an edge
    // naming it may mean either of them, and guessing joins two types the
    // build keeps apart — which is how a graph with no loop grows one.
    for (final entry in _claims.entries) {
      if (entry.value > 1) ambiguous.add(entry.key);
    }

    final nodes = {
      for (final entry in edges.entries)
        if (!ambiguous.contains(entry.key)) entry.key,
    };

    List<String>? cycle;
    try {
      layeredTopologicalSort<String>(
        nodes,
        (node) => edges[node]!.where(nodes.contains),
        labelOf: (node) => node,
      );
    } on CobaltCycleError catch (error) {
      cycle = error.cycle;
    }

    return CobaltRegistrationIndex(
      names,
      edges,
      ambiguous,
      cycle,
      lazy.difference(ambiguous),
    );
  }

  void collect(CompilationUnit unit) {
    for (final declaration in unit.declarations) {
      if (declaration is! ClassDeclaration) continue;

      final claimed = declaration.namePart.typeName.lexeme;
      _claims[claimed] = (_claims[claimed] ?? 0) + 1;

      var registers = false;
      var isModule = false;
      var isLazy = false;
      String? exposed;
      final wanted = <String>{};

      for (final annotation in declaration.metadata) {
        switch (annotation.name.name.split('.').last) {
          case 'CobaltInject':
          case 'cobaltInject':
          case 'cobaltSingleton':
          case 'cobaltTransient':
          case 'CobaltInit':
          case 'cobaltInit':
          case 'cobaltLazyInit':
            registers = true;
            isLazy =
                isLazy ||
                annotation.name.name.endsWith('cobaltLazyInit') ||
                _isTrue(_namedArgument(annotation, 'lazy'));
            names.add(declaration.namePart.typeName.lexeme);
            _addArgument(annotation, 'exposeAs', names);
            exposed ??= _firstName(_namedArgument(annotation, 'exposeAs'));
            _addArgumentList(annotation, 'dependsOn', wanted);
          case 'CobaltScopeRoot':
            _addArgumentList(annotation, 'provides', names);
          case 'CobaltModule':
          case 'cobaltModule':
            isModule = true;
        }
      }

      if (registers) {
        final node = exposed ?? declaration.namePart.typeName.lexeme;
        _addConstructorParameters(declaration, wanted);
        _addInjectedFields(declaration, wanted);
        _link(node, wanted);
        if (isLazy) lazy.add(node);
      }
      if (isModule) _collectMembers(declaration);
    }
  }

  /// Adds what a module's members register, and what they ask for.
  ///
  /// Only inside a class that says it is a module: a return type is a much
  /// weaker signal than an annotated class, and reading every method of every
  /// class would quietly answer for types nobody registers.
  void _collectMembers(ClassDeclaration module) {
    for (final member in membersOf(module)) {
      if (member is! MethodDeclaration) continue;
      for (final annotation in member.metadata) {
        switch (annotation.name.name.split('.').last) {
          case 'CobaltInject':
          case 'cobaltInject':
          case 'cobaltSingleton':
          case 'cobaltTransient':
            _addTypeAnnotation(member.returnType, names);
            _addArgument(annotation, 'exposeAs', names);

            final node =
                _firstName(_namedArgument(annotation, 'exposeAs')) ??
                _returnedName(member.returnType);
            if (node == null) continue;

            // A member registers by its return type, not by a declaration, so
            // the class-declaration count above never sees it. Without this a
            // module registering `Channel` and an unrelated `Channel` class
            // elsewhere in the package read as one node.
            _claims[node] = (_claims[node] ?? 0) + 1;
            if (_isTrue(_namedArgument(annotation, 'lazyInit'))) lazy.add(node);

            final wanted = <String>{};
            for (final parameter
                in member.parameters?.parameters ?? const <FormalParameter>[]) {
              _addParameter(parameter, const {}, wanted);
            }
            _link(node, wanted);
        }
      }
    }
  }

  /// Records that [node] depends on [wanted], or marks it [ambiguous].
  void _link(String node, Set<String> wanted) {
    if (edges.containsKey(node)) {
      ambiguous.add(node);
      return;
    }
    edges[node] = wanted;
  }

  /// Adds the types the first public generative constructor takes.
  ///
  /// `this.field` carries no type of its own, so the field declarations are
  /// read first to give it one.
  void _addConstructorParameters(ClassDeclaration node, Set<String> out) {
    final fieldTypes = <String, String>{};
    for (final member in membersOf(node)) {
      if (member is! FieldDeclaration) continue;
      final type = _returnedName(member.fields.type);
      if (type == null) continue;
      for (final variable in member.fields.variables) {
        fieldTypes[variable.name.lexeme] = type;
      }
    }

    for (final member in membersOf(node)) {
      if (member is! ConstructorDeclaration) continue;
      if (member.factoryKeyword != null) continue;
      if (member.name?.lexeme.startsWith('_') ?? false) continue;
      for (final parameter in member.parameters.parameters) {
        _addParameter(parameter, fieldTypes, out);
      }
      return;
    }
  }

  /// Adds the type one parameter contributes, if it names one.
  ///
  /// A `super.field` parameter is skipped: its type lives in a class this unit
  /// may not contain, and a missed edge only costs a cycle that goes
  /// unreported. An untyped `this.field` falls back to [fieldTypes].
  void _addParameter(
    FormalParameter parameter,
    Map<String, String> fieldTypes,
    Set<String> out,
  ) {
    final declared = _declaredBy(parameter);
    if (declared is SuperFormalParameter) return;
    if (_isCallSiteValue(parameter)) return;
    final name = declared.name?.lexeme;
    final type =
        _returnedName(_typeOf(declared)) ??
        (declared is FieldFormalParameter && name != null
            ? fieldTypes[name]
            : null);
    if (type != null) out.add(type);
  }

  /// The node that carries a parameter's declaration.
  ///
  /// Before analyzer 13, a parameter that can take a default value — every
  /// named one, and every optional positional one — arrives wrapped in a
  /// `DefaultFormalParameter`, so asking the outer node what kind of parameter
  /// it is answers about the wrapper. From 13 on there is no wrapper, and the
  /// class is gone. The wrapper's one [FormalParameter] child is the parameter
  /// it wraps, and no unwrapped parameter has one, so this finds the
  /// declaration on both sides without naming a class only one side has.
  /// `{@cobaltParam required this.id}` is the common shape here, and unwrapped
  /// it is a [FieldFormalParameter] like any other.
  static FormalParameter _declaredBy(FormalParameter parameter) =>
      parameter.childEntities.whereType<FormalParameter>().firstOrNull ??
      parameter;

  /// The type a parameter writes down, or null when it writes none.
  ///
  /// Read as the parameter's direct [TypeAnnotation] child: the getter lives
  /// on the subclasses before analyzer 13 and on [FormalParameter] after. A
  /// default value sits a level deeper, so `const <String>[]` in it is never
  /// taken for the type.
  ///
  /// A function-typed parameter has a return type rather than a type of its
  /// own; reading that would name the wrong thing, so it names nothing. Its
  /// parameter list is a child before 13 and a grandchild, under a suffix
  /// node, after.
  static TypeAnnotation? _typeOf(FormalParameter parameter) {
    for (final child in parameter.childEntities) {
      if (child is FormalParameterList) return null;
      if (child is AstNode &&
          child is! TypeAnnotation &&
          child.childEntities.any((entity) => entity is FormalParameterList)) {
        return null;
      }
    }
    return parameter.childEntities.whereType<TypeAnnotation>().firstOrNull;
  }

  /// Whether `@CobaltParam` marks this parameter.
  ///
  /// Such a value comes from the call site, so it is neither a dependency the
  /// package must register nor an edge that can close a cycle.
  static bool _isCallSiteValue(FormalParameter parameter) =>
      parameter.metadata.any((annotation) {
        final name = annotation.name.name.split('.').last;
        return name == 'CobaltParam' || name == 'cobaltParam';
      });

  void _addInjectedFields(ClassDeclaration node, Set<String> out) {
    for (final member in membersOf(node)) {
      if (member is! FieldDeclaration) continue;
      for (final annotation in member.metadata) {
        switch (annotation.name.name.split('.').last) {
          case 'Injected':
          case 'injected':
            final type = _returnedName(member.fields.type);
            if (type != null) out.add(type);
        }
      }
    }
  }

  /// Reads the name a return type registers.
  ///
  /// `Future<T>` registers `T`, matching the parser. Type arguments are
  /// otherwise ignored, as everywhere else in this index. A member with no
  /// written return type adds nothing — a silent miss, which is the direction
  /// this index is allowed to fail in.
  static void _addTypeAnnotation(TypeAnnotation? type, Set<String> names) {
    final name = _returnedName(type);
    if (name != null) names.add(name);
  }

  static String? _returnedName(TypeAnnotation? type) {
    if (type is! NamedType) return null;
    final name = type.name.lexeme;
    if (name != 'Future') return name;
    return _returnedName(type.typeArguments?.arguments.firstOrNull);
  }

  static void _addArgument(
    Annotation annotation,
    String parameter,
    Set<String> names,
  ) {
    final value = _namedArgument(annotation, parameter);
    if (value != null) _addExpression(value, names);
  }

  static void _addArgumentList(
    Annotation annotation,
    String parameter,
    Set<String> names,
  ) {
    final value = _namedArgument(annotation, parameter);
    if (value is! ListLiteral) return;
    for (final element in value.elements) {
      if (element is Expression) _addExpression(element, names);
    }
  }

  static String? _firstName(Expression? expression) {
    if (expression == null) return null;
    final found = <String>{};
    _addExpression(expression, found);
    return found.firstOrNull;
  }

  static Expression? _namedArgument(Annotation annotation, String parameter) {
    final arguments = annotation.arguments;
    if (arguments == null) return null;
    for (final argument in arguments.arguments) {
      if (_labelOf(argument) == parameter) return _valueOf(argument);
    }
    return null;
  }

  static String? _labelOf(AstNode argument) {
    final name = argument.beginToken;
    return name.next?.type == TokenType.COLON ? name.lexeme : null;
  }

  /// Whether [expression] is the literal `true` — the only spelling of
  /// `lazy: true` a syntactic index can read without guessing.
  static bool _isTrue(Expression? expression) =>
      expression is BooleanLiteral && expression.value;

  /// The value an argument carries, past its label if it has one.
  ///
  /// A named argument's value is its last [Expression] child in both shapes;
  /// a positional argument is an [Expression] itself on every analyzer.
  static Expression? _valueOf(AstNode argument) {
    if (_labelOf(argument) != null) {
      return argument.childEntities.whereType<Expression>().lastOrNull;
    }
    return argument is Expression ? argument : null;
  }

  /// Reads the type an expression names, in every shape `provides`,
  /// `exposeAs` and `dependsOn` accept: `Foo`, `prefix.Foo`,
  /// `Repository<User>` and `CobaltProvided(Foo, name: 'x')`.
  static void _addExpression(Expression expression, Set<String> names) {
    switch (expression) {
      case SimpleIdentifier(:final name):
        names.add(name);
      case PrefixedIdentifier(identifier: SimpleIdentifier(:final name)):
        names.add(name);
      case TypeLiteral(:final type):
        names.add(type.name.lexeme);
      // Unresolved, `Repository<User>` is ambiguous — the parser cannot tell a
      // generic type from a generic function, and only rewrites it to a
      // TypeLiteral during resolution, which this index never gets.
      case FunctionReference(:final function):
        _addExpression(function, names);
      case InstanceCreationExpression(:final argumentList):
        _addFirstArgument(argumentList, names);
      case MethodInvocation(:final argumentList):
        _addFirstArgument(argumentList, names);
    }
  }

  static void _addFirstArgument(ArgumentList arguments, Set<String> names) {
    final first = arguments.arguments.firstOrNull;
    if (first == null) return;
    final value = _valueOf(first);
    if (value != null) _addExpression(value, names);
  }
}

/// Keeps one [CobaltRegistrationIndex] per package, rebuilt when a file
/// changes.
///
/// The rules need the whole package to answer a question about one class, so
/// without this the package would be reparsed once per analysed library. What
/// makes caching affordable is that checking is far cheaper than building:
/// listing `lib` and reading modification stamps costs a stat per file,
/// parsing costs a parse per file.
class CobaltRegistrationIndexCache {
  final _byPackageRoot = <String, _CachedIndex>{};

  /// The index for the package rooted at [packageRoot], or null when it cannot
  /// be read whole.
  CobaltRegistrationIndex? of(Folder packageRoot, AnalysisSession session) {
    final lib = packageRoot.getChild('lib');
    if (lib is! Folder || !lib.exists) return null;

    final stamps = <String, int>{};
    _stamp(lib, stamps);

    final cached = _byPackageRoot[packageRoot.path];
    if (cached != null && cached.matches(stamps)) return cached.index;

    final index = CobaltRegistrationIndex.read(stamps.keys, session);
    if (index == null) return null;

    _byPackageRoot[packageRoot.path] = _CachedIndex(stamps, index);
    return index;
  }

  static void _stamp(Folder folder, Map<String, int> stamps) {
    for (final child in folder.getChildren()) {
      if (child is Folder) {
        _stamp(child, stamps);
      } else if (child is File && child.path.endsWith('.dart')) {
        stamps[child.path] = child.modificationStamp;
      }
    }
  }
}

class _CachedIndex {
  _CachedIndex(this.stamps, this.index);

  final Map<String, int> stamps;
  final CobaltRegistrationIndex index;

  bool matches(Map<String, int> other) {
    if (other.length != stamps.length) return false;
    for (final entry in other.entries) {
      if (stamps[entry.key] != entry.value) return false;
    }
    return true;
  }
}
