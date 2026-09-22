import 'package:cobalt/cobalt.dart';
import 'package:codegen_basics/services.dart';

/// Something expensive that only one screen wants.
///
/// `@cobaltLazyInit` keeps it out of startup: nothing builds it until the
/// first `getAsync`, which is what `CobaltAsyncBuilder` on the counter screen
/// does. After that it lives as long as the root scope, like any singleton.
///
/// `init` stands in for real work without a timer: a `Future.delayed` here
/// would never fire inside `testWidgets`, whose clock only moves when pumped.
@cobaltLazyInit
class Leaderboard implements AsyncInitializable {
  Leaderboard(this._repository);

  final Repository _repository;

  var entries = 0;

  @override
  Future<void> init() async {
    await Future<void>.value();
    entries = 3 + _repository.read('scores');
  }
}
