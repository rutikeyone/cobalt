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

final class CobaltRoot extends _i573.CobaltRootBuilder {
  const CobaltRoot();

  @override
  String get name => cobaltRootScopeName;

  @override
  void build(_i573.CobaltScope scope) {
    scope.registerLazySingleton<_i583.Clock>(const _ClockFactory());
    scope.registerLazySingleton<_i583.Greeter>(const _GreeterFactory());
  }
}

@Deprecated('Use CobaltRoot. Removed in 2.0.')
typedef $CobaltRootScope = CobaltRoot;
const String cobaltRootScopeName = 'root';
@Deprecated('Use cobaltRootScopeName. Removed in 2.0.')
const String $cobaltRootScopeName = cobaltRootScopeName;
_i687.Future<_i573.CobaltScope> startCobalt({
  List<_i573.CobaltOverride<Object>> overrides = const [],
  Duration? initTimeout,
}) => _i573.CobaltApplication.start(
  root: const CobaltRoot(),
  rootName: cobaltRootScopeName,
  overrides: overrides,
  initTimeout: initTimeout,
);
@Deprecated('Use startCobalt. Removed in 2.0.')
_i687.Future<_i573.CobaltScope> $startCobalt({
  List<_i573.CobaltOverride<Object>> overrides = const [],
  Duration? initTimeout,
}) => startCobalt(overrides: overrides, initTimeout: initTimeout);
