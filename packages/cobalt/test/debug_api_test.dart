// ignore_for_file: deprecated_member_use_from_same_package

import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  setUp(resetLogs);

  group('the deprecated read-only members', () {
    test('answer what the stable API answers', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const _DescribedLoggerFactory())
        ..decorate<Logger>(FnDecorator((inner, _) => inner), debugLabel: 'Kept')
        ..hookAll<Logger>(FnHook((_, _) {}), debugLabel: 'Seen')
        ..adopt(Greeting('hi'));
      final child = root.push('child');
      const key = CobaltKey(Logger);

      expect(child.debugKindOf(key), child.registrationOf(key)!.kind);
      expect(child.debugDecoratorsOf(key), ['Kept']);
      expect(child.debugImplementationOf(key), 'DescribedLogger');
      expect(root.debugAdopted, ['Greeting']);
      expect(root.debugHooks, ['Seen on Logger']);
      expect(root.debugDescribeTree(), root.describeTree());
    });

    test('answer null or empty for a key nothing registers', () {
      final scope = cobaltTestRoot();
      const key = CobaltKey(Logger);

      expect(scope.debugKindOf(key), isNull);
      expect(scope.debugDecoratorsOf(key), isEmpty);
      expect(scope.debugImplementationOf(key), isNull);
    });

    test('debugRegistrationsOf maps each previewed key to its kind', () {
      expect(
        CobaltScope.debugRegistrationsOf(
          _Graph(
            (scope) => scope
              ..registerLazySingleton<Logger>(const LoggerFactory())
              ..registerFactory<ApiClient>(const ApiClientFactory()),
          ),
        ),
        {
          const CobaltKey(Logger): Kind.lazySingleton,
          const CobaltKey(ApiClient): Kind.transient,
        },
      );
    });
  });

  group('debugResolve', () {
    test('builds the same instance the typed get would', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());

      expect(
        scope.debugResolve(const CobaltKey(Logger)),
        same(scope.get<Logger>()),
      );
    });

    test('is null for a key nothing registers', () {
      expect(cobaltTestRoot().debugResolve(const CobaltKey(Logger)), isNull);
    });

    test('throws what get throws for an async singleton before init', () {
      final scope = cobaltTestRoot()
        ..registerAsyncSingleton<SlowService>(const SlowFactory('db', 0));

      expect(
        () => scope.debugResolve(const CobaltKey(SlowService)),
        throwsA(isA<CobaltNotReadyError>()),
      );
    });

    test('throws for a parameterized registration', () {
      final scope = cobaltTestRoot()
        ..registerParamFactory<PropertyTarget, String>(
          const TargetByNameFactory(),
        );

      expect(
        () => scope.debugResolve(const CobaltKey(PropertyTarget)),
        throwsA(isA<CobaltError>()),
      );
    });
  });
}

typedef Kind = CobaltRegistrationKind;

class TargetByNameFactory
    implements CobaltParamFactory<PropertyTarget, String> {
  const TargetByNameFactory();

  @override
  PropertyTarget create(CobaltResolver resolver, String param) =>
      PropertyTarget();
}

final class _DescribedLoggerFactory
    implements CobaltFactory<Logger>, CobaltDescribedFactory {
  const _DescribedLoggerFactory();

  @override
  String get implementation => 'DescribedLogger';

  @override
  Logger create(CobaltResolver resolver) => Logger();
}

final class _Graph implements CobaltScopeBuilder {
  const _Graph(this.build_);
  final void Function(CobaltScope scope) build_;

  @override
  void build(CobaltScope scope) => build_(scope);
}
