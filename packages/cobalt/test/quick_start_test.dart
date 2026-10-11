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

  final appTest = File(
    '${root.path}/examples/hello/test/home_screen_test.dart',
  ).readAsStringSync().replaceAll('package:hello/', 'package:my_app/');

  for (final name in [
    'README.md',
    'README.ru.md',
    'README.zh-CN.md',
    'README.ko.md',
  ]) {
    test('$name shows the test of examples/hello for my_app', () {
      expect(
        File('${root.path}/$name').readAsStringSync(),
        contains('```dart\n$appTest```'),
      );
    });
  }
}
