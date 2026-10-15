import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/audit_trail.dart';

@CobaltChildScope()
class Visit {
  const Visit(this.visitor);

  final String visitor;
}

@CobaltInject(scope: Visit)
class Greeting {
  Greeting(this.visitor);

  final String visitor;

  String get text => 'Hello, $visitor';
}

@CobaltDecorates(Greeting)
class LoudGreeting implements Greeting {
  LoudGreeting(this.inner, this._trail);

  final Greeting inner;
  final AuditTrail _trail;

  @override
  String get visitor => inner.visitor;

  @override
  String get text {
    _trail.record('greeting handed out');
    return inner.text.toUpperCase();
  }
}
