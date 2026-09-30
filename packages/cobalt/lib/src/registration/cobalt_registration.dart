import 'dart:async';

import 'package:cobalt/src/factory/cobalt_async_factory.dart';
import 'package:cobalt/src/factory/cobalt_async_param_factory.dart';
import 'package:cobalt/src/factory/cobalt_factory.dart';
import 'package:cobalt/src/factory/cobalt_param_factory.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

part 'async_param_registration.dart';
part 'async_singleton_registration.dart';
part 'async_transient_registration.dart';
part 'lazy_async_singleton_registration.dart';
part 'lazy_singleton_registration.dart';
part 'param_registration.dart';
part 'singleton_registration.dart';
part 'transient_registration.dart';

/// Closes an instance the scope owns whose type Cobalt cannot recognise.
///
/// Erased to `Object` because a registration cannot carry its own `T`. The
/// typed callback the caller passes is wrapped at registration time.
typedef CobaltTeardown = FutureOr<void> Function(Object instance);

sealed class CobaltRegistration {
  CobaltRegistration({
    required this.key,
    required this.order,
    this.implementation,
  });

  final CobaltKey key;
  final int order;

  /// What the factory says it builds, when it says — see
  /// `CobaltDescribedFactory`.
  final String? implementation;
}
