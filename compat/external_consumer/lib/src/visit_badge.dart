import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/visit.dart';

@CobaltInject(scope: Visit)
@CobaltEnvironment.prod
class VisitBadge {
  VisitBadge(@Named('visitor') this.visitor);

  final String visitor;
}
