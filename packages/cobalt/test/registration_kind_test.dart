import 'package:cobalt/cobalt.dart';
import 'package:test/test.dart';

/// The answers tools read instead of switching over the values, spelled out
/// once per kind — a new kind has to take a row here, which is the point.
void main() {
  const table = {
    //                                          retained, param, async, init
    CobaltRegistrationKind.singleton: (true, false, false, false),
    CobaltRegistrationKind.lazySingleton: (true, false, false, false),
    CobaltRegistrationKind.transient: (false, false, false, false),
    CobaltRegistrationKind.asyncSingleton: (true, false, true, true),
    CobaltRegistrationKind.lazyAsyncSingleton: (true, false, true, false),
    CobaltRegistrationKind.parameterized: (false, true, false, false),
    CobaltRegistrationKind.asyncParameterized: (false, true, true, false),
    CobaltRegistrationKind.asyncTransient: (false, false, true, false),
  };

  test('every kind has a row', () {
    expect(table.keys, unorderedEquals(CobaltRegistrationKind.values));
  });

  for (final MapEntry(key: kind, value: row) in table.entries) {
    test(kind.name, () {
      final (retained, param, async, init) = row;
      expect(kind.isRetained, retained, reason: 'isRetained');
      expect(kind.takesParam, param, reason: 'takesParam');
      expect(kind.isAsync, async, reason: 'isAsync');
      expect(kind.isBuiltByInit, init, reason: 'isBuiltByInit');
    });
  }
}
