import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

import 'support.dart';

typedef Kind = CobaltRegistrationKind;

void main() {
  setUp(resetLogs);

  group('CobaltRegistrationInfo', () {
    CobaltRegistrationInfo info({
      Kind kind = Kind.lazySingleton,
      String? implementation = 'LiveLogger',
      List<String> decorators = const ['Logged', 'Cached'],
      bool isOverridden = true,
    }) => CobaltRegistrationInfo(
      key: const CobaltKey(Logger, name: 'audit'),
      kind: kind,
      implementation: implementation,
      decorators: decorators,
      isOverridden: isOverridden,
    );

    test('is equal by value, decorators by their contents', () {
      final a = info(decorators: ['Logged', 'Cached']);
      final b = info(decorators: ['Logged', 'Cached']);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs in every field', () {
      expect(info(kind: Kind.transient), isNot(info()));
      expect(info(implementation: null), isNot(info()));
      expect(info(decorators: ['Cached', 'Logged']), isNot(info()));
      expect(info(isOverridden: false), isNot(info()));
      expect(
        const CobaltRegistrationInfo(
          key: CobaltKey(Logger),
          kind: Kind.singleton,
        ),
        isNot(
          const CobaltRegistrationInfo(
            key: CobaltKey(ApiClient),
            kind: Kind.singleton,
          ),
        ),
      );
    });

    test('reads as the key, its kind and what is set', () {
      expect(
        info().toString(),
        'Logger(audit): lazySingleton, implementation: LiveLogger, '
        'decorators: Logged, Cached, overridden',
      );
      expect(
        const CobaltRegistrationInfo(
          key: CobaltKey(Logger),
          kind: Kind.transient,
        ).toString(),
        'Logger: transient',
      );
    });
  });

  group('CobaltHookInfo', () {
    test('is equal by label and type', () {
      const a = CobaltHookInfo(label: 'Seen', type: Logger);
      final b = CobaltHookInfo(label: 'Seen', type: Logger);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const CobaltHookInfo(label: 'Other', type: Logger)));
      expect(a, isNot(const CobaltHookInfo(label: 'Seen', type: ApiClient)));
    });

    test('reads as its label on its type', () {
      expect(
        const CobaltHookInfo(label: 'Seen', type: Logger).toString(),
        'Seen on Logger',
      );
    });
  });

  group('registrationOf', () {
    test('names every kind of registration', () {
      final scope = cobaltTestRoot()
        ..registerSingleton<Greeting>(Greeting('hi'))
        ..registerEagerSingleton<Greeting>(
          FnFactory((_) => Greeting('eager')),
          name: 'eager',
        )
        ..registerLazySingleton<Logger>(const LoggerFactory())
        ..registerFactory<ApiClient>(const ApiClientFactory())
        ..registerAsyncSingleton<SlowService>(const SlowFactory('db', 0))
        ..registerLazyAsyncSingleton<SlowService>(
          const SlowFactory('lazy', 0),
          name: 'lazy',
        )
        ..registerAsyncFactory<SlowService>(
          const SlowFactory('fresh', 0),
          name: 'fresh',
        )
        ..registerParamFactory<PropertyTarget, String>(
          FnParamFactory((_, _) => PropertyTarget()),
        )
        ..registerAsyncParamFactory<PropertyTarget, String>(
          AsyncFnParamFactory((_, _) async => PropertyTarget()),
          name: 'async',
        );

      Kind? kindOf(Type type, [String? name]) =>
          scope.registrationOf(CobaltKey(type, name: name))?.kind;

      expect(kindOf(Greeting), Kind.singleton);
      expect(kindOf(Greeting, 'eager'), Kind.singleton);
      expect(kindOf(Logger), Kind.lazySingleton);
      expect(kindOf(ApiClient), Kind.transient);
      expect(kindOf(SlowService), Kind.asyncSingleton);
      expect(kindOf(SlowService, 'lazy'), Kind.lazyAsyncSingleton);
      expect(kindOf(SlowService, 'fresh'), Kind.asyncTransient);
      expect(kindOf(PropertyTarget), Kind.parameterized);
      expect(kindOf(PropertyTarget, 'async'), Kind.asyncParameterized);
    });

    test('carries the key it was asked for', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory(), name: 'audit');

      expect(
        scope.registrationOf(const CobaltKey(Logger, name: 'audit'))?.key,
        const CobaltKey(Logger, name: 'audit'),
      );
    });

    test('is null for a key nothing registers', () {
      expect(cobaltTestRoot().registrationOf(const CobaltKey(Logger)), isNull);
    });

    test('answers through ancestors, like get does', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const _DescribedLoggerFactory())
        ..decorate<Logger>(FnDecorator((inner, _) => inner), debugLabel: 'A');

      expect(
        root.push('child').registrationOf(const CobaltKey(Logger)),
        const CobaltRegistrationInfo(
          key: CobaltKey(Logger),
          kind: Kind.lazySingleton,
          implementation: 'DescribedLogger',
          decorators: ['A'],
        ),
      );
    });

    test('names the implementation a described factory says, else null', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const _DescribedLoggerFactory())
        ..registerLazySingleton<Logger>(const LoggerFactory(), name: 'plain')
        ..registerSingleton<Greeting>(Greeting('hi'));

      expect(
        scope.registrationOf(const CobaltKey(Logger))?.implementation,
        'DescribedLogger',
      );
      expect(
        scope
            .registrationOf(const CobaltKey(Logger, name: 'plain'))
            ?.implementation,
        isNull,
      );
      expect(
        scope.registrationOf(const CobaltKey(Greeting))?.implementation,
        isNull,
      );
    });

    test('lists decorators in the order they apply, innermost first', () {
      final scope = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory())
        ..decorate<Logger>(FnDecorator((inner, _) => inner), debugLabel: 'A')
        ..decorateAll<Logger>(FnDecorator((inner, _) => inner))
        ..decorate<Logger>(FnDecorator((inner, _) => inner), debugLabel: 'C');

      final decorators = scope
          .registrationOf(const CobaltKey(Logger))!
          .decorators;

      expect(decorators, ['A', 'FnDecorator<Logger>', 'C']);
      expect(() => decorators.add('D'), throwsUnsupportedError);
    });

    test('reports the decorators of the scope that owns the key', () {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory())
        ..decorate<Logger>(FnDecorator((inner, _) => inner), debugLabel: 'A');
      final child = root.push('child')
        ..decorate<Logger>(FnDecorator((inner, _) => inner), debugLabel: 'B');

      expect(child.registrationOf(const CobaltKey(Logger))?.decorators, ['A']);
    });

    test('is overridden only in the scope the override is applied to', () {
      final root = cobaltTestRoot(
        overrides: [CobaltOverride<Greeting>.value(Greeting('fake'))],
      )..registerLazySingleton<Logger>(const LoggerFactory());
      final child = root.push(
        'child',
        overrides: [CobaltOverride<Logger>.lazy(FnFactory((_) => Logger()))],
      );

      expect(
        root.registrationOf(const CobaltKey(Greeting))?.isOverridden,
        isTrue,
      );
      expect(
        child.registrationOf(const CobaltKey(Greeting))?.isOverridden,
        isTrue,
        reason: 'answered for the root, which owns it',
      );
      expect(
        child.registrationOf(const CobaltKey(Logger))?.isOverridden,
        isTrue,
      );
      expect(
        root.registrationOf(const CobaltKey(Logger))?.isOverridden,
        isFalse,
      );
    });

    test('does not throw once the scope is disposed', () async {
      final root = cobaltTestRoot()
        ..registerLazySingleton<Logger>(const LoggerFactory());
      final child = root.push('child')
        ..registerFactory<ApiClient>(const ApiClientFactory());
      await child.dispose();

      expect(child.registrationOf(const CobaltKey(ApiClient)), isNull);
      expect(
        child.registrationOf(const CobaltKey(Logger))?.kind,
        Kind.lazySingleton,
      );
    });
  });

  group('previewRegistrations', () {
    test('lists what the builder registers, in order, building nothing', () {
      var built = 0;
      final preview = CobaltScope.previewRegistrations(
        _Graph(
          (scope) => scope
            ..registerFactory<ApiClient>(const ApiClientFactory())
            ..registerEagerSingleton<Logger>(
              FnFactory((_) {
                built++;
                return Logger();
              }),
            )
            ..registerLazySingleton<Logger>(
              const _DescribedLoggerFactory(),
              name: 'described',
            )
            ..decorate<ApiClient>(
              FnDecorator((inner, _) => inner),
              debugLabel: 'Logged',
            ),
        ),
      );

      expect(preview, const [
        CobaltRegistrationInfo(
          key: CobaltKey(ApiClient),
          kind: Kind.transient,
          decorators: ['Logged'],
        ),
        CobaltRegistrationInfo(key: CobaltKey(Logger), kind: Kind.singleton),
        CobaltRegistrationInfo(
          key: CobaltKey(Logger, name: 'described'),
          kind: Kind.lazySingleton,
          implementation: 'DescribedLogger',
        ),
      ]);
      expect(built, 0, reason: 'an eager registration is recorded, not built');
      expect(() => preview.add(preview.first), throwsUnsupportedError);
    });

    test('throws what the builder throws', () {
      expect(
        () => CobaltScope.previewRegistrations(
          _Graph((scope) => throw StateError('broken builder')),
        ),
        throwsStateError,
      );
    });
  });

  group('hooks', () {
    test('lists the hooks added to the scope itself, in order', () {
      final root = cobaltTestRoot()
        ..hookAll<Logger>(FnHook((_, _) {}), debugLabel: 'Seen')
        ..hookAll<ApiClient>(FnHook((_, _) {}));
      final child = root.push('child');

      expect(root.hooks, const [
        CobaltHookInfo(label: 'Seen', type: Logger),
        CobaltHookInfo(label: 'FnHook<ApiClient>', type: ApiClient),
      ]);
      expect(child.hooks, isEmpty, reason: "an ancestor's are not its own");
      expect(() => root.hooks.add(root.hooks.first), throwsUnsupportedError);
    });

    test('is empty after dispose', () async {
      final scope = cobaltTestRoot()..hookAll<Logger>(FnHook((_, _) {}));
      await scope.dispose();

      expect(scope.hooks, isEmpty);
    });
  });

  group('adoptedTypes', () {
    test('lists what was adopted, in order, by type', () {
      final scope = cobaltTestRoot()
        ..adopt(Greeting('hi'))
        ..adopt(Logger());

      expect(scope.adoptedTypes, [Greeting, Logger]);
      expect(() => scope.adoptedTypes.add(Logger), throwsUnsupportedError);
    });

    test('is empty after dispose', () async {
      final scope = cobaltTestRoot()..adopt(Logger());
      await scope.dispose();

      expect(scope.adoptedTypes, isEmpty);
    });
  });

  group('describeTree', () {
    test('renders one line per scope, children indented', () async {
      final root = cobaltTestRoot(name: 'app')
        ..registerLazySingleton<Logger>(const LoggerFactory());
      root.push('session').push('flow');
      final closed = root.push('closed');
      await closed.dispose();

      expect(
        root.describeTree(),
        'app  [open]  1 registration(s)\n'
        '  session  [open]  0 registration(s)\n'
        '    flow  [open]  0 registration(s)',
      );
      expect(closed.describeTree(), 'closed  [disposed]  0 registration(s)');
    });
  });
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
