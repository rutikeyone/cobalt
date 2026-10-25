import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/visit.dart';

@CobaltInject(scope: Visit)
@CobaltEnvironment.prod
class VisitBadge {
  VisitBadge(this.visitor);

  final String visitor;
}
