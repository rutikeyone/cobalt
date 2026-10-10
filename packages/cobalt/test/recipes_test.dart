@Tags(['repo'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory('../..');

  const pages = [
    'docs/RECIPES.md',
    'docs/RECIPES.ru.md',
    'docs/RECIPES.zh-CN.md',
    'docs/RECIPES.ko.md',
  ];

  final excerpt = RegExp(
    r'<!-- from: (\S+) -->\n\n```dart\n(.*?)\n```',
    dotAll: true,
  );

  List<(String, String)> excerptsOf(String page) => [
    for (final match in excerpt.allMatches(
      File('${root.path}/$page').readAsStringSync(),
    ))
      (match.group(1)!, match.group(2)!),
  ];

  String dedent(List<String> lines) {
    final indents = [
      for (final line in lines)
        if (line.trim().isNotEmpty) line.length - line.trimLeft().length,
    ];
    final common = indents.isEmpty
        ? 0
        : indents.reduce((a, b) => a < b ? a : b);
    return [
      for (final line in lines)
        line.trim().isEmpty ? '' : line.substring(common),
    ].join('\n');
  }

  bool quotes(String source, String code) {
    final lines = source.split('\n');
    final length = code.split('\n').length;
    for (var start = 0; start + length <= lines.length; start++) {
      if (dedent(lines.sublist(start, start + length)) == code) return true;
    }
    return false;
  }

  test('the English page has a recipe for each of its sections', () {
    expect(excerptsOf(pages.first), hasLength(greaterThanOrEqualTo(5)));
  });

  for (final page in pages) {
    group(page, () {
      for (final (path, code) in excerptsOf(page)) {
        test('quotes $path as it is', () {
          final file = File('${root.path}/$path');
          expect(file.existsSync(), isTrue, reason: '$path is gone');
          expect(
            quotes(file.readAsStringSync(), code),
            isTrue,
            reason: 'the code on the page no longer matches $path',
          );
        });
      }
    });
  }

  for (final page in pages.skip(1)) {
    test('$page shows the same code as the English page', () {
      expect(excerptsOf(page), excerptsOf(pages.first));
    });
  }
}
