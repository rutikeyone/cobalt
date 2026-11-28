import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// The members of a class, or nothing when it has no body to hold any.
///
/// `class Foo;` has an [EmptyClassBody] and declares nothing, which is the
/// reason this is not a plain `body.members`. It is also the reason the same
/// expression compiles against every analyzer this package supports: the
/// getter sits on [ClassBody] in analyzer 12 and on [BlockClassBody] in
/// analyzer 10, and asking the subtype is right in both.
///
/// The range matters. A Flutter 3.38 application cannot resolve an analyzer
/// newer than 10.0.1 — Flutter pins `meta 1.17.0` there and 10.0.2 wants
/// `^1.18.0` — while everything above it takes 12.1.0.
Iterable<ClassMember> membersOf(ClassDeclaration declaration) =>
    switch (declaration.body) {
      BlockClassBody(:final members) => members,
      _ => const <ClassMember>[],
    };

PrimaryConstructorDeclaration? primaryConstructorOf(
  ClassDeclaration declaration,
) => switch (declaration.namePart) {
  final PrimaryConstructorDeclaration primary => primary,
  _ => null,
};

List<FormalParameter>? publicConstructorParametersOf(ClassDeclaration node) {
  final primary = primaryConstructorOf(node);
  if (primary != null && !_isPrivate(primary.constructorName?.name)) {
    return primary.formalParameters.parameters;
  }
  for (final member in membersOf(node)) {
    if (member is! ConstructorDeclaration) continue;
    if (member.factoryKeyword != null) continue;
    if (_isPrivate(member.name)) continue;
    return member.parameters.parameters;
  }
  return null;
}

bool _isPrivate(Token? name) => name?.lexeme.startsWith('_') ?? false;
