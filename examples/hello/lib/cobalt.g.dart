// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i687;

import 'package:cobalt/cobalt.dart' as _i573;
import 'package:hello/main.dart' as _i583;

final class _ClockFactory
    implements _i573.CobaltFactory<_i583.Clock>, _i573.CobaltDescribedFactory {
  const _ClockFactory();

  @override
  String get implementation => 'Clock';

  @override
  _i583.Clock create(_i573.CobaltResolver resolver) => _i583.Clock();
}

final class _GreeterFactory
    implements
        _i573.CobaltFactory<_i583.Greeter>,
        _i573.CobaltDescribedFactory {
  const _GreeterFactory();

  @override
  String get implementation => 'Greeter';

  @override
  _i583.Greeter create(_i573.CobaltResolver resolver) =>
      _i583.Greeter(resolver.get<_i583.Clock>());
}

final class $CobaltRootScope implements _i573.CobaltScopeBuilder {
  const $CobaltRootScope();

  @override
  void build(_i573.CobaltScope scope) {
    scope.registerLazySingleton<_i583.Clock>(const _ClockFactory());
    scope.registerLazySingleton<_i583.Greeter>(const _GreeterFactory());
  }
}

typedef CobaltRoot = $CobaltRootScope;
const String $cobaltRootScopeName = 'root';
_i687.Future<_i573.CobaltScope> $startCobalt({
  List<_i573.CobaltOverride<Object>> overrides = const [],
  Duration? initTimeout,
}) => _i573.CobaltApplication.start(
  root: const $CobaltRootScope(),
  rootName: $cobaltRootScopeName,
  overrides: overrides,
  initTimeout: initTimeout,
);
