// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:cobalt/cobalt.dart' as _i573;
import 'package:cobalt_external_consumer/src/archive.dart' as _i768;
import 'package:cobalt_external_consumer/src/audit_sink.dart' as _i604;
import 'package:cobalt_external_consumer/src/audit_trail.dart' as _i720;
import 'package:cobalt_external_consumer/src/audited_database.dart' as _i963;
import 'package:cobalt_external_consumer/src/bind_platform.dart' as _i366;
import 'package:cobalt_external_consumer/src/clock.dart' as _i612;
import 'package:cobalt_external_consumer/src/database.dart' as _i530;
import 'package:cobalt_external_consumer/src/device_info.dart' as _i829;
import 'package:cobalt_external_consumer/src/diagnostics.dart' as _i862;
import 'package:cobalt_external_consumer/src/license_check.dart' as _i1023;
import 'package:cobalt_external_consumer/src/note_editor.dart' as _i59;
import 'package:cobalt_external_consumer/src/platform_module.dart' as _i455;
import 'package:cobalt_external_consumer/src/report.dart' as _i1031;
import 'package:cobalt_external_consumer/src/reporter.dart' as _i879;
import 'package:cobalt_external_consumer/src/repository.dart' as _i242;
import 'package:cobalt_external_consumer/src/search_index.dart' as _i375;
import 'package:cobalt_external_consumer/src/session_cache.dart' as _i995;
import 'package:cobalt_external_consumer/src/system_clock.dart' as _i271;
import 'package:cobalt_external_consumer/src/telemetry.dart' as _i186;

typedef $NoteEditorArgs = ({int id, String title, bool draft});

final class _ArchiveFactory implements _i573.CobaltAsyncFactory<_i768.Archive> {
  const _ArchiveFactory();

  @override
  _i687.Future<_i768.Archive> create(_i573.CobaltResolver resolver) async {
    final instance = _i768.Archive(resolver.get<_i530.Database>());
    await instance.init();
    return instance;
  }
}

final class _ArchiveIndexFactory
    implements _i573.CobaltAsyncFactory<_i768.ArchiveIndex> {
  const _ArchiveIndexFactory();

  @override
  _i687.Future<_i768.ArchiveIndex> create(_i573.CobaltResolver resolver) async {
    final instance = _i768.ArchiveIndex(
      await resolver.getAsync<_i768.Archive>(),
    );
    await instance.init();
    return instance;
  }
}

final class _AuditSinkFactory
    implements _i573.CobaltAsyncFactory<_i604.AuditSink> {
  const _AuditSinkFactory();

  @override
  _i687.Future<_i604.AuditSink> create(_i573.CobaltResolver resolver) async {
    final instance = _i604.AuditSink();
    await instance.init();
    return instance;
  }
}

final class _AuditTrailFactory
    implements _i573.CobaltAsyncFactory<_i720.AuditTrail> {
  const _AuditTrailFactory();

  @override
  _i687.Future<_i720.AuditTrail> create(_i573.CobaltResolver resolver) async {
    final instance = _i720.AuditTrail(resolver.get<_i604.AuditSink>());
    await instance.init();
    return instance;
  }
}

final class _SystemClockFactory implements _i573.CobaltFactory<_i612.Clock> {
  const _SystemClockFactory();

  @override
  _i612.Clock create(_i573.CobaltResolver resolver) => _i271.SystemClock();
}

final class _DatabaseFactory
    implements _i573.CobaltAsyncFactory<_i530.Database> {
  const _DatabaseFactory();

  @override
  _i687.Future<_i530.Database> create(_i573.CobaltResolver resolver) async {
    final instance = _i530.Database();
    await instance.init();
    return instance;
  }
}

final class _DiagnosticsFactory
    implements _i573.CobaltFactory<_i862.Diagnostics> {
  const _DiagnosticsFactory();

  @override
  _i862.Diagnostics create(_i573.CobaltResolver resolver) => _i862.Diagnostics(
    resolver.get<_i829.DeviceInfo>(),
    resolver.get<_i612.Clock>(),
  );
}

final class _LicenseCheckFactory
    implements _i573.CobaltFactory<_i1023.LicenseCheck> {
  const _LicenseCheckFactory();

  @override
  _i1023.LicenseCheck create(_i573.CobaltResolver resolver) =>
      _i1023.LicenseCheck();
}

final class _NoteEditorFactory
    implements _i573.CobaltParamFactory<_i59.NoteEditor, $NoteEditorArgs> {
  const _NoteEditorFactory();

  @override
  _i59.NoteEditor create(_i573.CobaltResolver resolver, $NoteEditorArgs args) =>
      _i59.NoteEditor(
        resolver.get<_i612.Clock>(),
        id: args.id,
        title: args.title,
        draft: args.draft,
      );
}

final class _PlatformModuleChannelFactory
    implements _i573.CobaltFactory<_i455.Channel> {
  const _PlatformModuleChannelFactory();

  @override
  _i455.Channel create(_i573.CobaltResolver resolver) =>
      const _i455.PlatformModule().channel();
}

final class _PlatformModuleEnvelopeFactory
    implements _i573.CobaltAsyncFactory<_i455.Envelope> {
  const _PlatformModuleEnvelopeFactory();

  @override
  _i687.Future<_i455.Envelope> create(_i573.CobaltResolver resolver) async =>
      await const _i455.PlatformModule().envelope(
        channel: resolver.get<_i455.Channel>(),
      );
}

final class _ReportFactory implements _i573.CobaltFactory<_i1031.Report> {
  const _ReportFactory();

  @override
  _i1031.Report create(_i573.CobaltResolver resolver) => _i1031.Report();
}

final class _ReporterFactory implements _i573.CobaltFactory<_i879.Reporter> {
  const _ReporterFactory();

  @override
  _i879.Reporter create(_i573.CobaltResolver resolver) => _i879.Reporter(
    resolver.get<_i612.Clock>(),
    resolver.getOrNull<_i186.Telemetry>(),
  );
}

final class _CatalogFactory implements _i573.CobaltFactory<_i242.Catalog> {
  const _CatalogFactory();

  @override
  _i242.Catalog create(_i573.CobaltResolver resolver) => _i242.Catalog(
    resolver.get<_i242.Repository<_i242.User>>(),
    resolver.get<_i242.Repository<_i242.Order>>(),
  );
}

final class _OrderRepositoryFactory
    implements _i573.CobaltFactory<_i242.Repository<_i242.Order>> {
  const _OrderRepositoryFactory();

  @override
  _i242.Repository<_i242.Order> create(_i573.CobaltResolver resolver) =>
      _i242.OrderRepository();
}

final class _UserRepositoryFactory
    implements _i573.CobaltFactory<_i242.Repository<_i242.User>> {
  const _UserRepositoryFactory();

  @override
  _i242.Repository<_i242.User> create(_i573.CobaltResolver resolver) =>
      _i242.UserRepository();
}

final class _SearchIndexFactory
    implements _i573.CobaltAsyncFactory<_i375.SearchIndex> {
  const _SearchIndexFactory();

  @override
  _i687.Future<_i375.SearchIndex> create(_i573.CobaltResolver resolver) async {
    final instance = _i375.SearchIndex(resolver.get<_i530.Database>());
    await instance.init();
    return instance;
  }
}

final class _SessionCacheFactory
    implements _i573.CobaltFactory<_i995.SessionCache> {
  const _SessionCacheFactory();

  @override
  _i995.SessionCache create(_i573.CobaltResolver resolver) =>
      _i995.SessionCache();
}

final class _AuditedDatabaseDecorator
    implements _i573.CobaltDecorator<_i530.Database> {
  const _AuditedDatabaseDecorator();

  @override
  _i530.Database decorate(
    _i530.Database inner,
    _i573.CobaltResolver resolver,
  ) => _i963.AuditedDatabase(inner, resolver.get<_i720.AuditTrail>());
}

final class $CobaltRootScope implements _i573.CobaltScopeBuilder {
  const $CobaltRootScope();

  @override
  void build(_i573.CobaltScope scope) {
    scope.registerAsyncSingleton<_i604.AuditSink>(const _AuditSinkFactory());
    scope.registerLazySingleton<_i612.Clock>(const _SystemClockFactory());
    scope.registerEagerSingleton<_i1023.LicenseCheck>(
      const _LicenseCheckFactory(),
    );
    scope.registerLazySingleton<_i455.Channel>(
      const _PlatformModuleChannelFactory(),
      dispose: _i455.closeChannel,
    );
    scope.registerLazySingleton<_i242.Repository<_i242.Order>>(
      const _OrderRepositoryFactory(),
    );
    scope.registerLazySingleton<_i242.Repository<_i242.User>>(
      const _UserRepositoryFactory(),
    );
    scope.registerLazySingleton<_i995.SessionCache>(
      const _SessionCacheFactory(),
      dispose: _i995.closeSessionCache,
    );
    scope.registerAsyncSingleton<_i720.AuditTrail>(
      const _AuditTrailFactory(),
      dependsOn: {const _i573.CobaltKey(_i604.AuditSink)},
    );
    scope.registerLazySingleton<_i862.Diagnostics>(const _DiagnosticsFactory());
    scope.registerParamFactory<_i59.NoteEditor, $NoteEditorArgs>(
      const _NoteEditorFactory(),
    );
    scope.registerAsyncSingleton<_i455.Envelope>(
      const _PlatformModuleEnvelopeFactory(),
    );
    scope.registerLazySingleton<_i879.Reporter>(const _ReporterFactory());
    scope.registerLazySingleton<_i242.Catalog>(const _CatalogFactory());
    scope.registerAsyncSingleton<_i530.Database>(const _DatabaseFactory());
    scope.registerLazyAsyncSingleton<_i768.Archive>(const _ArchiveFactory());
    scope.registerAsyncSingleton<_i375.SearchIndex>(
      const _SearchIndexFactory(),
      dependsOn: {
        const _i573.CobaltKey(_i530.Database),
        const _i573.CobaltKey(_i720.AuditTrail),
      },
    );
    scope.registerLazyAsyncSingleton<_i768.ArchiveIndex>(
      const _ArchiveIndexFactory(),
    );
    scope.registerFactory<_i1031.Report>(const _ReportFactory());
    scope.decorate<_i530.Database>(
      const _AuditedDatabaseDecorator(),
      debugLabel: 'AuditedDatabase',
    );
  }
}

List<_i573.CobaltBootstrapStep> get $cobaltBootstrap => [_i366.BindPlatform()];
const String $cobaltRootScopeName = 'consumer';
_i687.Future<_i573.CobaltScope> $startCobalt({
  List<_i573.CobaltOverride<Object>> overrides = const [],
}) => _i573.CobaltApplication.start(
  root: const $CobaltRootScope(),
  bootstrap: $cobaltBootstrap,
  rootName: $cobaltRootScopeName,
  overrides: overrides,
);
