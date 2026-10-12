import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_lint/src/registration_index.dart';
import 'package:cobalt_lint/src/rules/dependency_is_not_registered.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// Moves a root class into the child scope that registers what it injects:
/// `@cobaltInject` becomes `@CobaltInject(scope: Session)`.
///
/// Offered only where the move is the one answer: the class is registered in
/// the root, exactly one child scope registers the dependency, and its marker
/// and the annotation it writes resolve in this library without a new import.
/// A module member is left alone, since the diagnostic sits on the module.
class AddScopeArgument extends ResolvedCorrectionProducer {
  /// Creates the producer for the diagnostic in [context].
  AddScopeArgument({required super.context});

  static const _kind = FixKind(
    'cobalt.fix.addScopeArgument',
    DartFixKindPriority.standard,
    "Register the class in scope '{0}'",
  );

  static const _parser = CobaltInjectableParser();

  String? _scope;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String>? get fixArguments => _scope == null ? null : [_scope!];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final declaration = node.thisOrAncestorOfType<ClassDeclaration>();
    final element = declaration?.declaredFragment?.element;
    if (declaration == null || element == null) return;
    if (!_parser.declares(element)) return;

    final List<CobaltInjectableClass> parsed;
    try {
      parsed = _parser.parseClass(element);
    } on CobaltParseError {
      return;
    }
    if (parsed.any((each) => each.scope != null)) return;

    final index = _index();
    if (index == null) return;
    final scopes = <String>{
      for (final each in parsed) ...?firstOutOfScope(each, index)?.scopes,
    };
    if (scopes.length != 1) return;
    final scope = scopes.single;
    if (!_isMarker(scope)) return;

    final edit = _edit(declaration, scope);
    if (edit == null) return;
    _scope = scope;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(edit.range, edit.text);
    });
  }

  ({SourceRange range, String text})? _edit(
    ClassDeclaration declaration,
    String scope,
  ) {
    for (final annotation in declaration.metadata) {
      final name = annotation.name.name;
      final arguments = annotation.arguments;
      final bare = name.split('.').last;
      final rewritten = switch (bare) {
        'cobaltInject' => 'CobaltInject(scope: $scope)',
        'cobaltSingleton' =>
          'CobaltInject(lifetime: CobaltLifetime.singleton, scope: $scope)',
        'cobaltTransient' =>
          'CobaltInject(lifetime: CobaltLifetime.transient, scope: $scope)',
        'cobaltInit' => 'CobaltInit(scope: $scope)',
        'cobaltLazyInit' => 'CobaltInit(lazy: true, scope: $scope)',
        _ => null,
      };
      if (rewritten != null && arguments == null) {
        if (name != bare) return null;
        final needed = rewritten.split('(').first;
        if (!_resolvesToAnnotations(needed)) return null;
        if (rewritten.contains('CobaltLifetime') &&
            !_resolvesToAnnotations('CobaltLifetime')) {
          return null;
        }
        return (
          range: SourceRange(annotation.name.offset, annotation.name.length),
          text: rewritten,
        );
      }
      if ((bare == 'CobaltInject' || bare == 'CobaltInit') &&
          arguments != null) {
        final existing = arguments.arguments;
        if (existing.isEmpty) {
          return (
            range: SourceRange(arguments.leftParenthesis.end, 0),
            text: 'scope: $scope',
          );
        }
        return (
          range: SourceRange(existing.last.end, 0),
          text: ', scope: $scope',
        );
      }
    }
    return null;
  }

  bool _isMarker(String name) {
    final found = unitResult.libraryFragment.scope.lookup(name).getter;
    return found is ClassElement && childScopeMatcher.matches(found);
  }

  bool _resolvesToAnnotations(String name) {
    final found = unitResult.libraryFragment.scope.lookup(name).getter;
    final uri = found?.library?.uri;
    return uri != null &&
        uri.scheme == 'package' &&
        uri.pathSegments.first == 'cobalt_annotations';
  }

  CobaltRegistrationIndex? _index() {
    final provider = unitResult.session.resourceProvider;
    Folder? folder = provider.getFile(file).parent;
    while (folder != null) {
      final pubspec = folder.getChild('pubspec.yaml');
      if (pubspec is File && pubspec.exists) {
        return CobaltRegistrationIndexCache().of(folder, unitResult.session);
      }
      final parent = folder.parent;
      folder = parent.path == folder.path ? null : parent;
    }
    return null;
  }
}
