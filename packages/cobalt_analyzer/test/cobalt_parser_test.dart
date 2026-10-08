import 'dart:convert';

import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The one parser that reads a whole library rather than a class, and the one
/// this package's own suite never called: it was reached only through the
/// generator's tests and the compat stand, which left it hostage to somebody
/// else's coverage.
void main() {
  const parser = CobaltParser();

  test('collects each kind of declaration from one library', () async {
    final library = await libraryFrom('''
@CobaltScopeRoot(name: 'app')
class AppScope {
  const AppScope();
}

@cobaltBootstrap
class BindPlatform {
  BindPlatform();
  void run() {}
}

@cobaltInject
class Logger {
  Logger();
}

class Channel {}

@cobaltModule
class PlatformModule {
  const PlatformModule();

  @cobaltInject
  Channel channel() => Channel();
}
''');

    final declarations = parser.parseLibrary(library);

    expect(declarations.scopeRoots.single.name, 'app');
    expect(declarations.bootstrapSteps.single.type.name, 'BindPlatform');
    expect(
      declarations.injectables.map((each) => each.type.name),
      ['Logger', 'Channel'],
      reason: 'classes first, then what modules provide',
    );
    expect(declarations.injectables.last.provider?.member, 'channel');
  });

  test('a generic class yields one registration per instantiation, and '
      'its type arguments survive the IR', () async {
    final library = await libraryFrom('''
class Note {}
class Tag {}
class Store<T> {}

@CobaltInject(instantiations: [Cache<Note>, Cache<Tag>])
class Cache<T> {
  Cache(this.store);
  final Store<T> store;
}
''');

    final declarations = CobaltLibraryDeclarations.fromJson(
      jsonDecode(jsonEncode(parser.parseLibrary(library).toJson()))
          as Map<String, dynamic>,
    );

    expect(declarations.injectables.map((each) => '${each.type}'), [
      'Cache<Note>',
      'Cache<Tag>',
    ]);
    expect(
      declarations.injectables.map(
        (each) => '${each.constructorParameters.single.type}',
      ),
      ['Store<Note>', 'Store<Tag>'],
    );
    expect(
      declarations.injectables.first.type.signature,
      isNot(declarations.injectables.last.type.signature),
    );
  });

  test('a library that declares nothing is empty, not null', () async {
    final library = await libraryFrom('''
class Plain {
  Plain();
}
''');

    final declarations = parser.parseLibrary(library);

    expect(declarations.isEmpty, isTrue);
    expect(declarations.injectables, isEmpty);
    expect(declarations.bootstrapSteps, isEmpty);
    expect(declarations.scopeRoots, isEmpty);
  });

  test('one bad declaration fails the whole library', () async {
    final library = await libraryFrom('''
@cobaltInject
class Fine {
  Fine();
}

@cobaltInject
abstract class Store {}
''');

    expect(
      () => parser.parseLibrary(library),
      throwsA(
        isA<CobaltParseError>().having(
          (error) => error.message,
          'message',
          allOf(contains('Store'), contains('abstract')),
        ),
      ),
      reason:
          'partial IR would make the container reject a graph that is only '
          'half read',
    );
  });
}
