// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;
import 'dart:math' as _i407;

import 'package:cobalt/cobalt.dart' as _i573;
import 'package:codegen_basics/counter_bloc.dart' as _i1015;
import 'package:codegen_basics/greeting.dart' as _i767;
import 'package:codegen_basics/leaderboard.dart' as _i761;
import 'package:codegen_basics/platform_module.dart' as _i122;
import 'package:codegen_basics/services.dart' as _i700;

typedef $GreetingArgs = ({String name, bool loud});

final class _PlatformModuleEventsFactory
    implements _i573.CobaltFactory<_i687.StreamController<String>> {
  const _PlatformModuleEventsFactory();

  @override
  _i687.StreamController<String> create(_i573.CobaltResolver resolver) =>
      const _i122.PlatformModule().events();
}

final class _PlatformModuleRandomFactory
    implements _i573.CobaltFactory<_i407.Random> {
  const _PlatformModuleRandomFactory();

  @override
  _i407.Random create(_i573.CobaltResolver resolver) =>
      const _i122.PlatformModule().random;
}

final class _CounterBlocFactory
    implements _i573.CobaltFactory<_i1015.CounterBloc> {
  const _CounterBlocFactory();

  @override
  _i1015.CounterBloc create(_i573.CobaltResolver resolver) =>
      _i1015.CounterBloc();
}

final class _GreetingFactory
    implements _i573.CobaltParamFactory<_i767.Greeting, $GreetingArgs> {
  const _GreetingFactory();

  @override
  _i767.Greeting create(_i573.CobaltResolver resolver, $GreetingArgs args) =>
      _i767.Greeting(
        resolver.get<_i700.Config>(),
        name: args.name,
        loud: args.loud,
      );
}

final class _LeaderboardFactory
    implements _i573.CobaltAsyncFactory<_i761.Leaderboard> {
  const _LeaderboardFactory();

  @override
  _i687.Future<_i761.Leaderboard> create(_i573.CobaltResolver resolver) async {
    final instance = _i761.Leaderboard(resolver.get<_i700.Repository>());
    await instance.init();
    return instance;
  }
}

final class _ConfigFactory implements _i573.CobaltFactory<_i700.Config> {
  const _ConfigFactory();

  @override
  _i700.Config create(_i573.CobaltResolver resolver) => _i700.Config();
}

final class _RepositoryFactory
    implements _i573.CobaltFactory<_i700.Repository> {
  const _RepositoryFactory();

  @override
  _i700.Repository create(_i573.CobaltResolver resolver) =>
      _i700.Repository(resolver.get<_i700.Config>());
}

final class _TelemetryFactory implements _i573.CobaltFactory<_i700.Telemetry> {
  const _TelemetryFactory();

  @override
  _i700.Telemetry create(_i573.CobaltResolver resolver) => _i700.Telemetry();
}

final class $CobaltRootScope implements _i573.CobaltScopeBuilder {
  const $CobaltRootScope();

  @override
  void build(_i573.CobaltScope scope) {
    scope.registerLazySingleton<_i687.StreamController<String>>(
      const _PlatformModuleEventsFactory(),
      dispose: _i122.closeEvents,
    );
    scope.registerLazySingleton<_i407.Random>(
      const _PlatformModuleRandomFactory(),
    );
    scope.registerLazySingleton<_i700.Config>(const _ConfigFactory());
    scope.registerLazySingleton<_i700.Telemetry>(const _TelemetryFactory());
    scope.registerParamFactory<_i767.Greeting, $GreetingArgs>(
      const _GreetingFactory(),
    );
    scope.registerLazySingleton<_i700.Repository>(const _RepositoryFactory());
    scope.registerFactory<_i1015.CounterBloc>(const _CounterBlocFactory());
    scope.registerLazyAsyncSingleton<_i761.Leaderboard>(
      const _LeaderboardFactory(),
    );
  }
}

const String $cobaltRootScopeName = 'root';
_i687.Future<_i573.CobaltScope> $startCobalt({
  List<_i573.CobaltOverride<Object>> overrides = const [],
}) => _i573.CobaltApplication.start(
  root: const $CobaltRootScope(),
  rootName: $cobaltRootScopeName,
  overrides: overrides,
);
