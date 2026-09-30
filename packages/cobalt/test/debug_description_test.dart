import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

abstract interface class Api {}

class LiveApi implements Api {}

final class _LiveApiFactory
    implements CobaltFactory<Api>, CobaltDescribedFactory {
  const _LiveApiFactory();

  @override
  String get implementation => 'LiveApi';

  @override
  Api create(CobaltResolver resolver) => LiveApi();
}

class Step {}

void main() {
  group('debugImplementationOf', () {
    test('is what a described factory says, for every way of registering', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Api>(const _LiveApiFactory())
        ..registerEagerSingleton<Api>(const _LiveApiFactory(), name: 'eager')
        ..registerFactory<Api>(const _LiveApiFactory(), name: 'fresh');

      for (final name in [null, 'eager', 'fresh']) {
        expect(
          scope.debugImplementationOf(CobaltKey(Api, name: name)),
          'LiveApi',
          reason: '$name',
        );
      }
    });

    test('is null for a factory that does not say, or a value', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Api>(FnFactory((_) => LiveApi()))
        ..registerSingleton<Api>(LiveApi(), name: 'value');

      expect(scope.debugImplementationOf(const CobaltKey(Api)), isNull);
      expect(
        scope.debugImplementationOf(const CobaltKey(Api, name: 'value')),
        isNull,
      );
    });

    test('is answered from a scope below, for what an ancestor owns', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Api>(const _LiveApiFactory());

      expect(
        root.push('child').debugImplementationOf(const CobaltKey(Api)),
        'LiveApi',
      );
    });
  });

  group('debugRegistrationsOf', () {
    test('lists every key with its kind, and builds nothing', () {
      var built = 0;
      final registrations = CobaltScope.debugRegistrationsOf(
        _Graph(
          (scope) => scope
            ..registerEagerSingleton<Api>(
              FnFactory((_) {
                built++;
                return LiveApi();
              }),
            )
            ..registerLazySingleton<Api>(
              FnFactory((_) {
                built++;
                return LiveApi();
              }),
              name: 'lazy',
            )
            ..registerFactory<Step>(FnFactory((_) => Step())),
        ),
      );

      expect(registrations, {
        const CobaltKey(Api): CobaltRegistrationKind.singleton,
        const CobaltKey(Api, name: 'lazy'):
            CobaltRegistrationKind.lazySingleton,
        const CobaltKey(Step): CobaltRegistrationKind.transient,
      });
      expect(built, 0, reason: 'an eager registration is recorded, not built');
    });

    test('throws what the builder throws', () {
      expect(
        () => CobaltScope.debugRegistrationsOf(
          _Graph((scope) => throw StateError('broken builder')),
        ),
        throwsStateError,
      );
    });
  });

  test('debugAdopted lists what was adopted, in order, by type', () {
    final scope = cobaltTestRoot()
      ..adopt(Step())
      ..adopt(LiveApi());

    expect(scope.debugAdopted, ['Step', 'LiveApi']);
  });
}

final class _Graph implements CobaltScopeBuilder {
  const _Graph(this.build_);
  final void Function(CobaltScope scope) build_;

  @override
  void build(CobaltScope scope) => build_(scope);
}
