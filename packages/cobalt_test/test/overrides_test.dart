import 'package:cobalt/cobalt.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:test/test.dart';

final class Clock {
  const Clock(this.now);

  final int now;
}

final class _Graph implements CobaltScopeBuilder {
  const _Graph();

  @override
  void build(CobaltScope scope) =>
      scope.registerLazySingleton<Clock>(const ValueFactory(Clock(1)));
}

void main() {
  test('cobaltTestScope hands overrides to startup', () async {
    final scope = await cobaltTestScope(
      root: const _Graph(),
      overrides: [const CobaltOverride<Clock>.value(Clock(42))],
    );

    expect(scope.get<Clock>().now, 42);
  });

  test('cobaltTestRoot hands overrides to the root', () {
    final scope = cobaltTestRoot(
      overrides: [const CobaltOverride<Clock>.value(Clock(7))],
    )..registerLazySingleton<Clock>(const ValueFactory(Clock(1)));

    expect(scope.get<Clock>().now, 7);
  });

  test('pushForTest hands overrides to the child it pushes', () {
    final child = cobaltTestRoot().pushForTest('screen', [
      const CobaltOverride<Clock>.value(Clock(9)),
    ])..registerLazySingleton<Clock>(const ValueFactory(Clock(1)));

    expect(child.get<Clock>().now, 9);
    expect(child.overriddenKeys, {const CobaltKey(Clock)});
  });
}
