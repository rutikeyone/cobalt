import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A translation that lost a key comes back in English for that one line.
///
/// gen-l10n only warns about it, and the result reads as a rendering bug
/// rather than as a gap in the translation — so the gap is made a failure.
void main() {
  Set<String> keysOf(String locale) {
    final decoded =
        jsonDecode(File('l10n/graph_events_$locale.arb').readAsStringSync())
            as Map<String, dynamic>;
    return decoded.keys.where((key) => !key.startsWith('@')).toSet();
  }

  test('every translation covers the template, key for key', () {
    final template = keysOf('en');
    expect(template, isNotEmpty);

    for (final locale in ['ru', 'zh', 'ko']) {
      expect(keysOf(locale), template);
    }
  });
}
