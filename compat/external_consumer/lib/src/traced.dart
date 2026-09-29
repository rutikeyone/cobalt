import 'package:cobalt/cobalt.dart';

/// Something whose every build is written into the [BuiltLog] — by a hook,
/// not by the registrations that build it.
abstract interface class Traced {}

/// What the hook wrote, in the order it was built.
@cobaltInject
class BuiltLog {
  final entries = <String>[];
}

/// A lazy singleton that is [Traced].
@cobaltInject
class Ledger implements Traced {}

/// A transient that is [Traced]: every resolution is a build.
@cobaltTransient
class Receipt implements Traced {}

/// Writes every [Traced] the graph builds into the [BuiltLog].
@cobaltHookAll
class LogTraced implements CobaltHook<Traced> {
  const LogTraced();

  @override
  void onBuilt(Traced instance, CobaltResolver resolver) =>
      resolver.get<BuiltLog>().entries.add('${instance.runtimeType}');
}
