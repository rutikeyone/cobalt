import 'dart:convert';
import 'dart:io';

import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/builder.dart';
import 'package:cobalt_generator/src/builders/container_builder.dart';
import 'package:cobalt_generator/src/emitters/container_source_emitter.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:test/test.dart';

import 'builder_support.dart';

/// Sources live under `cobalt_generator` so the resolver has this package's
/// dependencies in hand.
const _pkg = 'cobalt_generator';

void main() {
  final builder = cobaltScanBuilder(const BuilderOptions({}));
  late PackageConfig packages;
  late Map<String, Object> deps;

  setUpAll(() async {
    packages = (await findPackageConfig(Directory.current))!;
    deps = sourcesOf(packages, 'cobalt_annotations')
      ..addAll(sourcesOf(packages, 'meta'));
  });

  group('the scan builder', () {
    test('leaves a library with no annotations alone', () async {
      await testBuilder(
        builder,
        {...deps, '$_pkg|lib/plain.dart': 'class Plain {\n  Plain();\n}\n'},
        packageConfig: packages,
        generateFor: {'$_pkg|lib/plain.dart'},
        outputs: const {},
      );
    });

    test('writes IR that decodes back into declarations', () async {
      String? written;

      await testBuilder(
        builder,
        {
          ...deps,
          '$_pkg|lib/graph.dart': '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

@cobaltInject
class Logger {
  Logger();
}

@cobaltInject
class Api {
  Api(this.logger);
  final Logger logger;
}
''',
        },
        packageConfig: packages,
        generateFor: {'$_pkg|lib/graph.dart'},
        outputs: {
          '$_pkg|lib/graph.cobalt.json': decodedMatches(
            predicate<String>((value) {
              written = value;
              return true;
            }),
          ),
        },
      );

      final decoded = CobaltLibraryDeclarations.fromJson(
        jsonDecode(written!) as Map<String, dynamic>,
      );
      expect(
        decoded.injectables.map((declaration) => declaration.type.name),
        containsAll(['Logger', 'Api']),
        reason:
            'an empty result here would mean the annotations resolved to '
            'nothing, not that the library declares nothing',
      );
      expect(
        decoded.injectables
            .firstWhere((declaration) => declaration.type.name == 'Api')
            .constructorParameters
            .single
            .type
            .name,
        'Logger',
      );
    });

    /// Both phases over one source: the scan writes one declaration per
    /// instantiation, and the container registers each under its own type
    /// with a factory of its own.
    test('registers every instantiation a generic class lists', () async {
      String? written;

      await testBuilder(
        builder,
        {
          ...deps,
          '$_pkg|lib/caches.dart': '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

class Note {}

class User {}

abstract interface class Store<T> {}

@CobaltInject(exposeAs: Store<Note>)
class NoteStore implements Store<Note> {
  NoteStore();
}

@CobaltInject(exposeAs: Store<User>)
class UserStore implements Store<User> {
  UserStore();
}

@CobaltInject(instantiations: [Cache<Note>, Cache<User>])
class Cache<T> {
  Cache(this.store);
  final Store<T> store;
}
''',
        },
        packageConfig: packages,
        generateFor: {'$_pkg|lib/caches.dart'},
        outputs: {
          '$_pkg|lib/caches.cobalt.json': decodedMatches(
            predicate<String>((value) {
              written = value;
              return true;
            }),
          ),
        },
      );

      String? container;
      await testBuilder(
        const CobaltContainerBuilder(),
        {'$_pkg|lib/caches.cobalt.json': written!},
        rootPackage: _pkg,
        outputs: {
          '$_pkg|lib/cobalt.g.dart': decodedMatches(
            predicate<String>((value) {
              container = value;
              return true;
            }),
          ),
        },
      );

      final source = container!
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'_i\d+\.'), '')
          .replaceAll('( ', '(')
          .replaceAll(', )', ')');
      for (final type in ['Note', 'User']) {
        expect(
          source,
          contains(
            'final class _CacheOf${type}Factory implements '
            'CobaltFactory<Cache<$type>>, CobaltDescribedFactory',
          ),
        );
        expect(
          source,
          contains("String get implementation => 'Cache<$type>';"),
        );
        expect(
          source,
          contains(
            'Cache<$type> create(CobaltResolver resolver) => '
            'Cache<$type>(resolver.get<Store<$type>>());',
          ),
        );
        expect(
          source,
          contains(
            'scope.registerLazySingleton<Cache<$type>>('
            'const _CacheOf${type}Factory());',
          ),
        );
      }
    });

    /// Both phases over one source: an `@injected` field of a generic class
    /// is a dependency of each instantiation, under that instantiation's own
    /// type arguments.
    group('an @injected field of a generic class', () {
      Future<CobaltLibraryDeclarations> scan({required bool userRepo}) async {
        String? written;
        await testBuilder(
          builder,
          {
            ...deps,
            '$_pkg|lib/injected_caches.dart':
                '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

class Note {}

class User {}

class Repo<T> {}

@CobaltInject(exposeAs: Repo<Note>)
class NoteRepo implements Repo<Note> {
  NoteRepo();
}
${userRepo ? '''
@CobaltInject(exposeAs: Repo<User>)
class UserRepo implements Repo<User> {
  UserRepo();
}
''' : ''}
@CobaltInject(instantiations: [Cache<Note>, Cache<User>])
class Cache<T> {
  Cache();

  @injected
  late final Repo<T> repo;
}
''',
          },
          packageConfig: packages,
          generateFor: {'$_pkg|lib/injected_caches.dart'},
          outputs: {
            '$_pkg|lib/injected_caches.cobalt.json': decodedMatches(
              predicate<String>((value) {
                written = value;
                return true;
              }),
            ),
          },
        );
        return CobaltLibraryDeclarations.fromJson(
          jsonDecode(written!) as Map<String, dynamic>,
        );
      }

      test('is read once per instantiation', () async {
        final declarations = await scan(userRepo: true);
        final caches = declarations.injectables.where(
          (declaration) => declaration.type.name == 'Cache',
        );

        expect(caches.map((cache) => '${cache.properties.single.type}'), [
          'Repo<Note>',
          'Repo<User>',
        ]);
        expect(
          () => const ContainerSourceEmitter().emit(declarations),
          returnsNormally,
        );
      });

      test('fails the build for the instantiation missing it', () async {
        final declarations = await scan(userRepo: false);

        expect(
          () => const ContainerSourceEmitter().emit(declarations),
          throwsA(
            isA<CobaltGenerationError>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('Cache<User> requires Repo<User>'),
                isNot(contains('Cache<Note> requires')),
              ),
            ),
          ),
        );
      });
    });

    group('a generic class exposed under a generic interface', () {
      Future<CobaltLibraryDeclarations> scan(String feed) async {
        String? written;
        await testBuilder(
          builder,
          {
            ...deps,
            '$_pkg|lib/exposed_caches.dart':
                '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

class Note {}

class Tag {}

abstract interface class Store<T> {}

@CobaltInject(exposeAs: Store, instantiations: [Cache<Note>, Cache<Tag>])
class Cache<T> implements Store<T> {
  Cache();
}

@cobaltInject
class Feed {
  Feed(this.store);
  final $feed store;
}
''',
          },
          packageConfig: packages,
          generateFor: {'$_pkg|lib/exposed_caches.dart'},
          outputs: {
            '$_pkg|lib/exposed_caches.cobalt.json': decodedMatches(
              predicate<String>((value) {
                written = value;
                return true;
              }),
            ),
          },
        );
        return CobaltLibraryDeclarations.fromJson(
          jsonDecode(written!) as Map<String, dynamic>,
        );
      }

      test('registers each instantiation under its own interface', () async {
        final source = const ContainerSourceEmitter()
            .emit(await scan('Store<Note>'))
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'_i\d+\.'), '')
            .replaceAll('( ', '(')
            .replaceAll(', )', ')');

        for (final type in ['Note', 'Tag']) {
          expect(
            source,
            contains(
              'scope.registerLazySingleton<Store<$type>>('
              'const _CacheOf${type}Factory());',
            ),
          );
        }
        expect(source, contains('Feed(resolver.get<Store<Note>>())'));
      });

      test('an instantiation it does not list is missing', () async {
        final declarations = await scan('Store<int>');

        expect(
          () => const ContainerSourceEmitter().emit(declarations),
          throwsA(
            isA<CobaltGenerationError>().having(
              (error) => error.message,
              'message',
              contains('Feed requires Store<int>'),
            ),
          ),
        );
      });
    });

    /// A parse failure is reported, not thrown: build_runner catches it and
    /// logs it at severe, which is what fails the build for a real consumer.
    test('reports a declaration it cannot parse, and writes nothing', () async {
      final severe = <String>[];

      await testBuilder(
        builder,
        {
          ...deps,
          '$_pkg|lib/broken.dart': '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

@cobaltInject
abstract class Store {}
''',
        },
        packageConfig: packages,
        generateFor: {'$_pkg|lib/broken.dart'},
        outputs: const {},
        onLog: (LogRecord record) {
          if (record.level >= Level.SEVERE) severe.add(record.toString());
        },
      );

      expect(
        severe.join('\n'),
        allOf(contains('Store'), contains('abstract')),
        reason: 'the message has to name the class, not the builder',
      );
    });
  });
}
