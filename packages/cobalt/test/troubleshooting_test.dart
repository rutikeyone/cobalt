@Tags(['repo'])
library;

import 'dart:io';

import 'package:cobalt/cobalt.dart';
import 'package:cobalt/src/errors/troubleshooting_link.dart';
import 'package:test/test.dart';

void main() {
  final root = Directory('../..');

  final thrown = {
    for (final file
        in Directory('${root.path}/packages')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (file) =>
                  file.path.endsWith('.dart') && file.path.contains('/lib/'),
            ))
      for (final match in RegExp(
        r'^(?:final |base )?class (Cobalt\w*Error) extends (?:CobaltError|StateError)',
        multiLine: true,
      ).allMatches(file.readAsStringSync()))
        match.group(1)!,
  };

  test('there are errors to check', () {
    expect(thrown, containsAll(['CobaltError', 'CobaltCycleError']));
    expect(thrown, contains('CobaltNoScopeError'));
  });

  for (final name in [
    'TROUBLESHOOTING.md',
    'TROUBLESHOOTING.ru.md',
    'TROUBLESHOOTING.zh-CN.md',
    'TROUBLESHOOTING.ko.md',
  ]) {
    test('docs/$name has an entry for every error', () {
      final entries = RegExp(r'^### (Cobalt\w*Error)$', multiLine: true)
          .allMatches(File('${root.path}/docs/$name').readAsStringSync())
          .map((match) => match.group(1)!)
          .toSet();

      expect(thrown.difference({'CobaltError'}).difference(entries), isEmpty);
      expect(entries.difference(thrown), isEmpty);
    });
  }

  test('an error ends with the link to its entry', () {
    final error = CobaltNotRegisteredError(const CobaltKey(String), 'app');

    expect(
      error.toString(),
      endsWith('\nSee $troubleshootingPage#cobaltnotregisterederror'),
    );
    expect(error.message, isNot(contains(troubleshootingPage)));
  });

  test('a cycle ends with the link to its entry', () {
    expect(
      CobaltCycleError(const ['A', 'B', 'A']).toString(),
      endsWith('\nSee $troubleshootingPage#cobaltcycleerror'),
    );
  });
}
