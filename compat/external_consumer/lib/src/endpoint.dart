import 'package:cobalt/cobalt.dart';

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

/// Wraps every `Endpoint`, whatever its name, with one annotation.
@CobaltDecorates(Endpoint, allNames: true)
class TracedEndpoint implements Endpoint {
  TracedEndpoint(this.inner);

  final Endpoint inner;

  @override
  String get url => '${inner.url}?traced';
}
