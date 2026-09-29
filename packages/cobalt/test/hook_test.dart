import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

abstract interface class Loggable {}

class Api implements Loggable {}

class Cache implements Loggable {}

class Plain {}

class Session implements Loggable {
  Session(this.id);
  final String id;
}

class Tag {
  const Tag(this.name);
  final String name;
}

final class _Fn<T extends Object> implements CobaltFactory<T> {
  const _Fn(this._create);
  final T Function(CobaltResolver resolver) _create;

  @override
  T create(CobaltResolver resolver) => _create(resolver);
}

final class _AsyncFn<T extends Object> implements CobaltAsyncFactory<T> {
  const _AsyncFn(this._create);
  final Future<T> Function(CobaltResolver resolver) _create;

  @override
  Future<T> create(CobaltResolver resolver) => _create(resolver);
}

final class _SessionFactory implements CobaltParamFactory<Session, String> {
  const _SessionFactory();

  @override
  Session create(CobaltResolver resolver, String param) => Session(param);
}

/// Records what it saw, labelled, into a shared list.
final class _Seen<T extends Object> implements CobaltHook<T> {
  _Seen(this.label, this.log);
  final String label;
  final List<(String, Object)> log;

  @override
  void onBuilt(T instance, CobaltResolver resolver) =>
      log.add((label, instance));
}

final class _Wrap implements CobaltDecorator<Api> {
  const _Wrap();

  @override
  Api decorate(Api inner, CobaltResolver resolver) => _WrappedApi();
}

class _WrappedApi extends Api {}

void main() {
  group('a hook of a supertype', () {
    test('sees every instance of it, from any registration, and no other', () {
      final log = <(String, Object)>[];
      final scope = cobaltTestRoot()
        ..hookAll<Loggable>(_Seen('loggable', log))
        ..registerLazySingleton<Api>(_Fn((_) => Api()))
        ..registerFactory<Cache>(_Fn((_) => Cache()))
        ..registerLazySingleton<Plain>(_Fn((_) => Plain()))
        ..registerParamFactory<Session, String>(const _SessionFactory());

      final api = scope.get<Api>();
      final cache = scope.get<Cache>();
      scope.get<Plain>();
      final session = scope.getWithParam<Session, String>('a');

      expect(log.map((entry) => entry.$2), [
        same(api),
        same(cache),
        same(session),
      ]);
    });

    test('hands the instance on unchanged, once per build', () {
      final log = <(String, Object)>[];
      final scope = cobaltTestRoot()
        ..hookAll<Loggable>(_Seen('loggable', log))
        ..registerLazySingleton<Api>(_Fn((_) => Api()))
        ..registerFactory<Cache>(_Fn((_) => Cache()));

      final first = scope.get<Api>();
      expect(scope.get<Api>(), same(first));
      scope
        ..get<Cache>()
        ..get<Cache>();

      expect(log.where((entry) => entry.$2 is Api), hasLength(1));
      expect(log.where((entry) => entry.$2 is Cache), hasLength(2));
    });

    test('an eager singleton built after the hook passes through it', () {
      final log = <(String, Object)>[];
      cobaltTestRoot()
        ..hookAll<Loggable>(_Seen('loggable', log))
        ..registerEagerSingleton<Api>(_Fn((_) => Api()));

      expect(log, hasLength(1));
    });

    test('async builds pass through it too', () async {
      final log = <(String, Object)>[];
      final scope = cobaltTestRoot()
        ..hookAll<Loggable>(_Seen('loggable', log))
        ..registerAsyncSingleton<Api>(_AsyncFn((_) async => Api()))
        ..registerLazyAsyncSingleton<Cache>(_AsyncFn((_) async => Cache()));

      await scope.init();
      expect(log.map((entry) => entry.$2), [isA<Api>()]);

      await scope.getAsync<Cache>();
      expect(log.map((entry) => entry.$2), [isA<Api>(), isA<Cache>()]);
    });

    test('sees what the factory built, before a decorator wraps it', () {
      final log = <(String, Object)>[];
      final scope = cobaltTestRoot()
        ..hookAll<Loggable>(_Seen('loggable', log))
        ..registerLazySingleton<Api>(_Fn((_) => Api()))
        ..decorate<Api>(const _Wrap());

      final served = scope.get<Api>();

      expect(served, isA<_WrappedApi>());
      expect(log.single.$2, isNot(isA<_WrappedApi>()));
    });

    test('does not see a value handed over ready-made', () {
      final log = <(String, Object)>[];
      cobaltTestRoot()
        ..hookAll<Loggable>(_Seen('loggable', log))
        ..registerSingleton<Api>(Api())
        ..get<Api>();

      expect(log, isEmpty);
    });
  });

  group('scopes below', () {
    test("run their ancestors' hooks first, then their own", () {
      final log = <(String, Object)>[];
      final root = cobaltTestRoot()..hookAll<Loggable>(_Seen('root', log));
      final child = root.push('child')
        ..hookAll<Loggable>(_Seen('child', log))
        ..registerLazySingleton<Api>(_Fn((_) => Api()));

      child.get<Api>();

      expect(log.map((entry) => entry.$1), ['root', 'child']);
    });

    test('hand the hook the scope that built the instance', () {
      final tags = <String>[];
      final root = cobaltTestRoot()..hookAll<Loggable>(_TagReader(tags));
      root.push('child')
        ..registerSingleton<Tag>(const Tag('child'))
        ..registerLazySingleton<Api>(_Fn((_) => Api()))
        ..get<Api>();

      expect(tags, ['child']);
    });

    test("do not run a sibling's hooks", () {
      final log = <(String, Object)>[];
      final root = cobaltTestRoot();
      root.push('a').hookAll<Loggable>(_Seen('a', log));
      root.push('b')
        ..registerLazySingleton<Api>(_Fn((_) => Api()))
        ..get<Api>();

      expect(log, isEmpty);
    });
  });

  group('adding a hook', () {
    test('after the scope built something throws, naming the type', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Api>(_Fn((_) => Api()))
        ..get<Api>();

      expect(
        () => scope.hookAll<Loggable>(_Seen('late', [])),
        throwsA(
          isA<CobaltHookError>()
              .having((e) => e.type, 'type', Loggable)
              .having((e) => e.scopeName, 'scopeName', scope.name),
        ),
      );
    });

    test('after a scope below built something throws too', () {
      final root = cobaltTestRoot();
      root.push('child')
        ..registerLazySingleton<Api>(_Fn((_) => Api()))
        ..get<Api>();

      expect(
        () => root.hookAll<Loggable>(_Seen('late', [])),
        throwsA(isA<CobaltHookError>()),
      );
    });

    test('before anything is built is fine, whatever is registered', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Api>(_Fn((_) => Api()));

      expect(
        () => scope.hookAll<Loggable>(_Seen('early', [])),
        returnsNormally,
      );
    });
  });

  test('a hook that throws fails the call that asked', () {
    final scope = cobaltTestRoot()
      ..hookAll<Loggable>(const _Throwing())
      ..registerFactory<Cache>(_Fn((_) => Cache()));

    expect(() => scope.get<Cache>(), throwsA(isA<StateError>()));
  });
}

final class _TagReader implements CobaltHook<Loggable> {
  _TagReader(this.tags);
  final List<String> tags;

  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) =>
      tags.add(resolver.get<Tag>().name);
}

final class _Throwing implements CobaltHook<Loggable> {
  const _Throwing();

  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) =>
      throw StateError('hook failed');
}
