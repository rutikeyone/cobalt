import 'package:cobalt/cobalt.dart';
import 'package:cobalt_external_consumer/src/repository.dart';

@CobaltInject(instantiations: [Cache<User>, Cache<Order>])
class Cache<T> {
  Cache(this.repository);

  final Repository<T> repository;

  late final List<T> entries = repository.all();
}

@cobaltInject
class Shelf {
  Shelf(this.users);

  final Cache<User> users;
}
