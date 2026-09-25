import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/cobalt_external_consumer.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

void main() {
  late CobaltScope scope;

  setUp(() async {
    BootLog.clear();
    scope = await $startCobalt();
  });

  // The closing form, because the tests below hand `scope` a different graph.
  // No guard on the state: dispose() returns early when it already ran.
  tearDown(() => scope.dispose());

  test('the generated container is named by @CobaltScopeRoot', () {
    expect(scope.name, 'consumer');
  });

  test('a bootstrap step runs before the graph is built', () {
    expect(BootLog.entries, ['bind-platform']);
  });

  test(
    'a bootstrap step is released with the scope, and released last',
    () async {
      await scope.dispose();
      // The module's channel is closed on the way down too; the bootstrap step
      // was adopted before anything else existed, so it goes after all of it.
      expect(BootLog.entries, [
        'bind-platform',
        'channel closed',
        'bind-platform released',
      ]);
    },
  );

  test('a class that names its own dispose function is closed', () async {
    final cache = scope.get<SessionCache>();
    expect(cache.isClosed, isFalse);

    await scope.dispose();

    expect(
      cache.isClosed,
      isTrue,
      reason:
          'SessionCache implements neither Disposable nor AsyncDisposable and '
          'its closing method is not called dispose — every Bloc, Cubit and '
          'ChangeNotifier is this shape. The annotation is the only thing that '
          'can say how to close it, and the class parser used to accept the '
          'argument and drop it',
    );
    expect(BootLog.entries, contains('session-cache closed'));
  });

  test('exposeAs publishes the interface, not the implementation', () {
    expect(scope.get<Clock>(), isA<SystemClock>());
    expect(scope.isRegistered<SystemClock>(), isFalse);
  });

  test('dependsOn is honoured across async initializers', () {
    expect(scope.get<Database>().isOpen, isTrue);
    expect(scope.get<SearchIndex>().isBuilt, isTrue);
  });

  test('property injection fills late final fields', () {
    expect(
      scope.get<Report>().render(),
      'report 2026-08-23T00:00:00.000Z indexed=true',
    );
  });

  test('a transient is a fresh instance per resolution', () {
    expect(identical(scope.get<Report>(), scope.get<Report>()), isFalse);
  });

  test('two instantiations of one generic are separate registrations', () {
    expect(scope.get<Repository<User>>(), isA<UserRepository>());
    expect(scope.get<Repository<Order>>(), isA<OrderRepository>());
  });

  test('a generic dependency resolves the matching instantiation', () {
    final catalog = scope.get<Catalog>();
    expect(catalog.users.all().single.name, 'ada');
    expect(catalog.orders.all().map((order) => order.id), [1, 2]);
  });

  group('a module registers types the package does not own', () {
    test('a member becomes an ordinary registration', () {
      expect(scope.get<Channel>().name, 'channel');
    });

    test('an async member is built during startup and gets its argument', () {
      final envelope = scope.get<Envelope>();
      expect(envelope.stamp, 'stamped');
      expect(identical(envelope.channel, scope.get<Channel>()), isTrue);
    });

    test(
      'the dispose function closes it, after what was built on it',
      () async {
        final channel = scope.get<Channel>();
        scope.get<Envelope>();
        BootLog.clear();

        await scope.dispose();

        expect(channel.isOpen, isFalse);
        // The bootstrap step was adopted first, so it is released last; the
        // channel closes before it and after everything that used it.
        expect(BootLog.entries, ['channel closed', 'bind-platform released']);
      },
    );
  });

  group('an optional dependency', () {
    test('arrives null when the graph supplies nothing', () {
      expect(scope.get<Reporter>().telemetry, isNull);
      expect(scope.get<Reporter>().describe(), 'reporting disabled');
    });

    test('did not stop the required one beside it from resolving', () {
      expect(scope.get<Reporter>().clock, isA<SystemClock>());
    });

    test('getOrNull says absent where get would throw', () {
      expect(scope.getOrNull<Telemetry>(), isNull);
      expect(() => scope.get<Telemetry>(), throwsA(isA<CobaltError>()));
    });
  });

  group('a registration promised through provides', () {
    test('is not emitted by the generator, only trusted', () {
      expect(scope.isRegistered<DeviceInfo>(), isFalse);
    });

    test(
      'resolves once a builder composes it with the generated one',
      () async {
        await scope.dispose();
        scope = await startConsumer(device: const DeviceInfo('pixel'));

        expect(scope.get<Diagnostics>().describe(), startsWith('pixel at '));
      },
    );
  });

  // checkGraph's own tests run on fixtures. This is the first time it walks a
  // generated graph, and it does it from outside the workspace, where the
  // helper package resolves like any other dependency.
  group('checking the graph by running it', () {
    test('names the promised registration nothing keeps', () async {
      final report = await checkGraph(scope);

      expect(report.isComplete, isFalse);
      expect(
        report.failures.map((f) => f.key.toString()),
        contains(contains('Diagnostics')),
        reason: 'provides tells the build to trust; only running finds out',
      );
    });

    test('and reports it complete once a builder keeps it', () async {
      await scope.dispose();
      scope = await startConsumer(device: const DeviceInfo('pixel'));

      final report = await checkGraph(scope);

      expect(report.isComplete, isTrue, reason: '$report');
    });
  });

  group('a class taking values from the call site', () {
    test('is registered as a parameterized factory, not a plain one', () {
      expect(
        scope.debugKindOf(const CobaltKey(NoteEditor)),
        CobaltRegistrationKind.parameterized,
      );
      expect(
        () => scope.get<NoteEditor>(),
        throwsA(isA<CobaltParamRequiredError>()),
      );
    });

    test('takes its values by name and the rest from the graph', () {
      final editor = scope.getWithParam<NoteEditor, $NoteEditorArgs>((
        id: 7,
        title: 'notes',
        draft: true,
      ));

      expect(
        editor.describe(),
        '7 "notes" (draft) at 2026-08-23T00:00:00.000Z',
      );
      expect(
        editor.clock,
        isA<SystemClock>(),
        reason: 'the clock came from the container, the rest from here',
      );
    });

    test('builds a fresh one per call, and the scope keeps neither', () {
      final first = scope.getWithParam<NoteEditor, $NoteEditorArgs>((
        id: 1,
        title: 'a',
        draft: false,
      ));
      final second = scope.getWithParam<NoteEditor, $NoteEditorArgs>((
        id: 1,
        title: 'a',
        draft: false,
      ));

      expect(identical(first, second), isFalse);
    });
  });

  group('a lazy async registration, generated outside the workspace', () {
    test('is not built by startup', () {
      expect(
        scope.debugKindOf(const CobaltKey(Archive)),
        CobaltRegistrationKind.lazyAsyncSingleton,
      );
      expect(() => scope.get<Archive>(), throwsA(isA<CobaltLazyAsyncError>()));
    });

    test('is built by getAsync, with its lazy dependency awaited', () async {
      final index = await scope.getAsync<ArchiveIndex>();

      expect(index.isBuilt, isTrue);
      expect(index.archive, same(await scope.getAsync<Archive>()));
      expect(index.archive.database, same(scope.get<Database>()));
      expect(scope.get<ArchiveIndex>(), same(index));
    });
  });

  group('a decorator generated outside the workspace', () {
    test('wraps the async registration once, and everyone shares it', () {
      final database = scope.get<Database>();

      expect(database, isA<AuditedDatabase>());
      expect(database, same(scope.get<Database>()));
      expect(scope.get<AuditTrail>().lines, ['database handed out']);
    });

    test('an async consumer is built after what the decorator needs', () {
      expect(
        scope.get<SearchIndex>().isBuilt,
        isTrue,
        reason:
            'SearchIndex resolves Database while phase 1 runs; the decorator '
            'then asks for AuditTrail, which dependsOn has to have finished',
      );
    });

    test('names its wrapper for introspection', () {
      expect(
        scope.debugDecoratorsOf(const CobaltKey(Database)),
        ['AuditedDatabase'],
        reason: 'named after the annotated class, not the generated wrapper',
      );
    });
  });

  group('overrides handed to the generated start function', () {
    test('an eager singleton is built by the scope at startup', () {
      expect(scope.get<LicenseCheck>(), isNot(isA<_ValidLicense>()));
    });

    test('an overridden eager singleton is never built at all', () async {
      LicenseCheck.built = 0;
      final overridden = await $startCobalt(
        overrides: [CobaltOverride<LicenseCheck>.value(_ValidLicense())],
      );
      addTearDown(overridden.dispose);

      expect(overridden.get<LicenseCheck>(), isA<_ValidLicense>());
      expect(LicenseCheck.built, 0);
    });

    test('a replaced exposed type reaches the generated consumer', () async {
      final overridden = await $startCobalt(
        overrides: [CobaltOverride<Clock>.value(_FrozenClock())],
      );
      addTearDown(overridden.dispose);

      expect(overridden.get<Reporter>().clock, isA<_FrozenClock>());
    });

    test(
      'a replaced async singleton reaches a lazy build that needs it',
      () async {
        final database = Database()..isOpen = true;
        final overridden = await $startCobalt(
          overrides: [CobaltOverride<Database>.value(database)],
        );
        addTearDown(overridden.dispose);

        final archive = await overridden.getAsync<Archive>();

        expect(
          archive.database,
          isA<AuditedDatabase>().having(
            (d) => d.inner,
            'inner',
            same(database),
          ),
          reason: 'the decorator wraps what the override put in its place',
        );
        expect(
          overridden.get<SearchIndex>(),
          isA<SearchIndex>(),
          reason:
              'SearchIndex refuses a closed database; the double is handed '
              'over as it is, and init() is never called on it',
        );
      },
    );
  });

  group('the two modes in one graph', () {
    /// The direction the stand already had is generated-takes-hand-written:
    /// `Diagnostics` receives the `DeviceInfo` that `ConsumerScope`
    /// registered. This is the other one, and the chain runs through all
    /// three: hand-written `SupportBundle` <- generated `Diagnostics` <-
    /// hand-written `DeviceInfo`.
    test('a hand-written registration may take a generated one', () async {
      final app = await startConsumer(device: const DeviceInfo('pixel-9'));
      addTearDown(app.dispose);

      expect(app.get<SupportBundle>().summary, contains('pixel-9'));
    });

    /// Order inside build() is invisible to a lazy registration and decisive
    /// for an eager one, which is the shape a migration lands in: hand-written
    /// registrations at the top of the file, the generated container at the
    /// bottom. The message has to say that, or it reads as "you forgot to
    /// register this" about something registered three lines below.
    test('a hand-written eager registration cannot outrun the container', () {
      final scope = CobaltScope.root(name: 'test');
      addTearDown(scope.dispose);

      expect(
        () => scope.runBuilder(const _EagerFirst()),
        throwsA(
          isA<CobaltNotRegisteredError>()
              .having((it) => it.whileBuilding, 'whileBuilding', isTrue)
              .having(
                (it) => it.toString(),
                'message',
                contains('still being built'),
              ),
        ),
      );
    });
  });
}

/// Resolves a generated registration before the generated container has run.
class _EagerFirst implements CobaltScopeBuilder {
  const _EagerFirst();

  @override
  void build(CobaltScope scope) {
    scope
      ..registerSingleton<SupportBundle>(
        const SupportBundleFactory().create(scope),
      )
      ..registerSingleton<DeviceInfo>(const DeviceInfo('late'));
    const $CobaltRootScope().build(scope);
  }
}

final class _ValidLicense implements LicenseCheck {
  @override
  bool get isValid => true;
}

final class _FrozenClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2000);
}
