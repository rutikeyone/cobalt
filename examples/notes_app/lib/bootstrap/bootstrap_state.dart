import 'package:notes_app/bootstrap/boot_log.dart';
import 'package:notes_app/bootstrap/load_remote_config.dart';

/// Clears everything phase 0 writes outside the graph.
///
/// Bootstrap steps run before the container exists, so nothing can be injected
/// into them — the generated `cobaltBootstrapSteps` builds them with no arguments at
/// all. Whatever they record therefore has to live somewhere that outlives the
/// graph, which in this example means statics.
///
/// Standing alone that never showed: one process meant one graph. Hosted in the
/// gallery, where a visit builds a graph and leaving disposes it, the leftovers
/// of the last visit would otherwise be read as this one's.
void resetBootstrapState() {
  BootLog.reset();
  LoadRemoteConfig.reset();
}
