import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/emitters/injection_mixin_emitter.dart';
import 'package:cobalt_generator/src/errors/cobalt_generation_error.dart';
import 'package:test/test.dart';

import 'support.dart';

/// One instantiation of `@CobaltInject(instantiations: [...]) class Cache<T>`,
/// as the parser hands it over: the type carries its arguments, and the
/// constructor parameter reads `Store<Note>` where the class says `Store<T>`.
CobaltInjectableClass cacheOf(
  CobaltTypeRef argument, {
  String import = appImport,
  List<CobaltInjectedProperty>? constructor,
}) => CobaltInjectableClass(
  type: CobaltTypeRef(name: 'Cache', import: import, typeArguments: [argument]),
  lifetime: CobaltLifetime.lazySingleton,
  constructorParameters:
      constructor ??
      [
        CobaltInjectedProperty(
          field: 'store',
          type: ref('Store', of: [argument]),
        ),
      ],
  properties: const [],
);

CobaltInjectableClass storeOf(String argument) =>
    declare('${argument}Store', exposeAs: ref('Store', of: [ref(argument)]));

String _flat(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('generic registrations', () {
    test('two instantiations of one type do not collide', () {
      final source = generate([
        declare(
          'UserRepository',
          exposeAs: ref('Repository', of: [ref('User')]),
        ),
        declare(
          'OrderRepository',
          exposeAs: ref('Repository', of: [ref('Order')]),
        ),
      ]);

      expect(registrationsOf(source), hasLength(2));
      expect(source, contains('Repository<_i'));
    });

    test('a duplicate of the same instantiation is still rejected', () {
      expect(
        () => generate([
          declare('FastUsers', exposeAs: ref('Repository', of: [ref('User')])),
          declare('SlowUsers', exposeAs: ref('Repository', of: [ref('User')])),
        ]),
        throwsA(isA<CobaltGenerationError>()),
      );
    });

    test('instantiations are separate nodes in the dependency graph', () {
      final source = generate([
        declare(
          'Catalog',
          constructor: [
            CobaltInjectedProperty(
              field: 'users',
              type: ref('Repository', of: [ref('User')]),
            ),
          ],
        ),
        declare(
          'UserRepository',
          exposeAs: ref('Repository', of: [ref('User')]),
        ),
        declare(
          'OrderRepository',
          exposeAs: ref('Repository', of: [ref('Order')]),
          constructor: [
            CobaltInjectedProperty(field: 'catalog', type: ref('Catalog')),
          ],
        ),
      ]);

      expect(registrationsOf(source), hasLength(3));
    });
  });

  group('instantiations of an annotated generic class', () {
    test('each gets a factory named after its type arguments', () {
      final source = generate([
        storeOf('Note'),
        storeOf('User'),
        cacheOf(ref('Note')),
        cacheOf(ref('User')),
      ]);

      expect(source, contains('final class _CacheOfNoteFactory'));
      expect(source, contains('final class _CacheOfUserFactory'));
      expect(
        source,
        isNot(contains('final class _CacheFactory')),
        reason: 'two classes of one name would not compile',
      );
    });

    test('several type arguments are joined by And', () {
      final source = generate([
        CobaltInjectableClass(
          type: ref('Pair', of: [ref('String'), ref('int')]),
          lifetime: CobaltLifetime.lazySingleton,
          constructorParameters: const [],
          properties: const [],
        ),
      ]);

      expect(source, contains('final class _PairOfStringAndIntFactory'));
    });

    test('a nested type argument is spelled out in full', () {
      final source = generate([
        cacheOf(ref('List', of: [ref('Note')]), constructor: const []),
      ]);

      expect(source, contains('final class _CacheOfListOfNoteFactory'));
    });

    test('a nullable type argument is named and registered as nullable', () {
      final source = generate([
        cacheOf(ref('Note', isNullable: true), constructor: const []),
        cacheOf(ref('Note'), constructor: const []),
      ]);

      expect(source, contains('final class _CacheOfNullableNoteFactory'));
      expect(source, contains('final class _CacheOfNoteFactory'));
      expect(
        registrationsOf(source).where((line) => line.contains('Note?>')),
        hasLength(1),
        reason: 'Cache<Note?> and Cache<Note> are two types at runtime',
      );
    });

    test('the factory says which instantiation it builds', () {
      final source = _flat(generate([storeOf('Note'), cacheOf(ref('Note'))]));

      expect(source, contains("String get implementation => 'Cache<Note>';"));
      expect(
        source,
        contains("String get implementation => 'NoteStore';"),
        reason: 'a class without type arguments is described as before',
      );
    });

    test('two instantiations live in one graph, each with its own store', () {
      final generated = generate([
        storeOf('Note'),
        storeOf('User'),
        cacheOf(ref('Note')),
        cacheOf(ref('User')),
      ]);
      final source = _flat(generated);

      expect(registrationsOf(generated), hasLength(4));
      expect(
        source,
        matches(
          RegExp(
            r'Cache<_i\d+\.Note>\(resolver\.get<_i\d+\.Store<_i\d+\.Note>>\(\)\)',
          ),
        ),
      );
      expect(
        source,
        matches(
          RegExp(
            r'Cache<_i\d+\.User>\(resolver\.get<_i\d+\.Store<_i\d+\.User>>\(\)\)',
          ),
        ),
      );
    });

    test('a class depending on one instantiation is registered after it', () {
      final source = generate([
        declare(
          'Feed',
          constructor: [
            CobaltInjectedProperty(
              field: 'notes',
              type: ref('Cache', of: [ref('Note')]),
            ),
          ],
        ),
        storeOf('Note'),
        storeOf('User'),
        cacheOf(ref('Note')),
        cacheOf(ref('User')),
      ]);
      final registrations = registrationsOf(source);
      int indexOf(String factory) =>
          registrations.indexWhere((line) => line.contains(factory));

      expect(
        _flat(source),
        matches(RegExp(r'resolver\.get<_i\d+\.Cache<_i\d+\.Note>>\(\)')),
      );
      expect(
        indexOf('_FeedFactory'),
        greaterThan(indexOf('_CacheOfNoteFactory')),
      );
    });

    test('an instantiation nothing registers is named in full', () {
      expect(
        () => generate([
          declare(
            'Feed',
            constructor: [
              CobaltInjectedProperty(
                field: 'tags',
                type: ref('Cache', of: [ref('Tag')]),
              ),
            ],
          ),
          storeOf('Note'),
          cacheOf(ref('Note')),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (error) => error.message,
            'message',
            contains('Feed requires Cache<Tag>, which nothing registers'),
          ),
        ),
      );
    });

    test('an instantiation missing its own dependency is named in full', () {
      expect(
        () => generate([
          storeOf('Note'),
          cacheOf(ref('Note')),
          cacheOf(ref('User')),
        ]),
        throwsA(
          isA<CobaltGenerationError>().having(
            (error) => error.message,
            'message',
            contains('Cache<User> requires Store<User>'),
          ),
        ),
      );
    });

    test('call-site records are named after the instantiation too', () {
      CobaltInjectableClass withParam(String argument) =>
          cacheOf(ref(argument), constructor: [arg('limit', 'int')]);
      final source = generate([withParam('Note'), withParam('User')]);

      expect(source, contains(r'typedef $CacheOfNoteArgs'));
      expect(source, contains(r'typedef $CacheOfUserArgs'));
    });

    test('one instantiation of two same-named classes is told apart', () {
      final source = generate([
        cacheOf(
          ref('Note'),
          import: 'package:app/a.dart',
          constructor: const [],
        ),
        cacheOf(
          ref('Note'),
          import: 'package:app/b.dart',
          constructor: const [],
        ),
      ]);

      expect(
        RegExp(
          r'final class (_CacheOfNoteFactory\S*)',
        ).allMatches(source).map((match) => match.group(1)).toSet(),
        hasLength(2),
      );
    });
  });

  group('nullable dependencies', () {
    String mixinFor({required bool isNullable}) =>
        const InjectionMixinEmitter().emit(
          declare(
            'Report',
            properties: [
              CobaltInjectedProperty(
                field: '_clock',
                type: ref('Clock', isNullable: isNullable),
              ),
            ],
          ),
        );

    test('a nullable injected field reads through getOrNull', () {
      final source = mixinFor(isNullable: true);

      expect(source, contains('resolver.getOrNull<Clock>()'));
    });

    test('its setter accepts null, or the assignment would not compile', () {
      final source = mixinFor(isNullable: true);

      expect(source, contains('set _clock(Clock? value)'));
    });

    test('the type argument stays non-nullable, since T extends Object', () {
      final source = mixinFor(isNullable: true);

      expect(source, isNot(contains('<Clock?>')));
    });

    test('a required field is untouched', () {
      final source = mixinFor(isNullable: false);

      expect(source, contains('resolver.get<Clock>()'));
      expect(source, contains('set _clock(Clock value)'));
      expect(source, isNot(contains('getOrNull')));
    });
  });
}
