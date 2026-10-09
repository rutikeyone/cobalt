@Tags(['repo'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory('../..');
  final app = File(
    '${root.path}/examples/hello/lib/main.dart',
  ).readAsStringSync();

  for (final name in [
    'README.md',
    'README.ru.md',
    'README.zh-CN.md',
    'README.ko.md',
    'packages/cobalt_flutter/README.md',
    'packages/cobalt/example/example.md',
  ]) {
    test('$name shows examples/hello as its Quick start', () {
      expect(
        File('${root.path}/$name').readAsStringSync(),
        contains('```dart\n$app```'),
      );
    });
  }
}
