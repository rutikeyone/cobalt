import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/clock.dart';

part 'endpoint.g.dart';

abstract interface class Endpoint {
  String get url;
}

@CobaltInject(exposeAs: Endpoint, name: 'api')
class ApiEndpoint implements Endpoint {
  @override
  String get url => 'https://api.example.com';
}

@CobaltInject(exposeAs: Endpoint, name: 'cdn')
class CdnEndpoint implements Endpoint {
  @override
  String get url => 'https://cdn.example.com';
}

/// Wraps every `Endpoint`, whatever its name, with one annotation, and takes
/// what it needs through an `@injected` field rather than its constructor.
@CobaltDecorates(Endpoint, allNames: true)
class TracedEndpoint with _$TracedEndpoint implements Endpoint {
  TracedEndpoint(this.inner);

  final Endpoint inner;

  @injected
  late final Clock _clock;

  @override
  String get url => '${inner.url}?traced=${_clock.now().year}';
}
