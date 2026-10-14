import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/cobalt.g.dart';
import 'package:cobalt_external_consumer/src/device_info.dart';
import 'package:cobalt_external_consumer/src/support_bundle.dart';

/// The whole root scope: what the generator found, plus the one thing it
/// cannot know about.
///
/// `DeviceInfo` is registered first so it is released last — everything built
/// on top of it goes away before the value it describes does.
class ConsumerScope implements CobaltScopeBuilder {
  const ConsumerScope(this.device);

  final DeviceInfo device;

  @override
  void build(CobaltScope scope) {
    scope.registerSingleton<DeviceInfo>(device);
    const CobaltRoot().build(scope);

    // Registered after the generated container and lazily, both on purpose: a
    // hand-written registration may take a generated one, and a lazy factory
    // does not care which of them was written first. An eager one would —
    // see `a hand-written eager registration cannot outrun the container`.
    scope.registerLazySingleton<SupportBundle>(const SupportBundleFactory());
  }
}

/// Starts the graph the way an application would: composing the generated
/// container rather than calling `startCobalt` and hoping.
Future<CobaltScope> startConsumer({
  DeviceInfo device = const DeviceInfo('test-device'),
}) => CobaltApplication.start(
  root: ConsumerScope(device),
  bootstrap: cobaltBootstrapSteps,
  rootName: cobaltRootScopeName,
);
