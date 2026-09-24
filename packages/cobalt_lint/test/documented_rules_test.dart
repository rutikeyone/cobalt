import 'dart:io';

import 'package:test/test.dart';

/// Every rule that ships is named in the tables, and every table row is a rule.
///
/// A guard against drift this repository has walked into more than once: a
/// rule is added, the package README gets its row, and the neighbouring
/// documents keep their old count. `cobalt_injected_field_needs_an_injectable`
/// and `cobalt_param_needs_an_injectable` both shipped while all three root
/// READMEs still said nine rules and listed nine, and this package's own
/// `example/example.md` still said seven.
///
/// The Code-Gen guides are here for the same reason: their tables stayed at
/// twelve rules through two releases that added one each.
///
/// Prose cannot be checked for meaning. A table can be checked for rows, and
/// the rows are the half that goes stale.
void main() {
  final shipped = Directory('lib/src/rules')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => 'cobalt_${file.uri.pathSegments.last.split('.').first}')
      .toSet();

  const documents = {
    'README.md': 'the package README',
    '../../README.md': 'the root README',
    '../../README.ru.md': 'the Russian README',
    '../../README.zh-CN.md': 'the Chinese README',
    '../../GUIDE_CODEGEN.md': 'the Code-Gen guide',
    '../../GUIDE_CODEGEN.ru.md': 'the Russian Code-Gen guide',
    '../../GUIDE_CODEGEN.zh-CN.md': 'the Chinese Code-Gen guide',
  };

  /// The first cell of every row of the rule table.
  ///
  /// Found by contents rather than by heading: these documents hold other
  /// tables keyed the same way — packages, builders — and in three languages
  /// the heading above them is three different strings. A table that lists a
  /// rule is the rule table, whatever it is called.
  Set<String> tabulated(String path) {
    final rows = <String>{};
    var table = <String>{};

    for (final line in File(path).readAsLinesSync()) {
      final row = RegExp(r'^\| `(cobalt_[a-z_]+)` \|').firstMatch(line);
      if (row != null) {
        table.add(row.group(1)!);
        continue;
      }
      if (!line.startsWith('|')) {
        if (table.intersection(shipped).isNotEmpty) rows.addAll(table);
        table = {};
      }
    }
    if (table.intersection(shipped).isNotEmpty) rows.addAll(table);
    return rows;
  }

  test('there is a rule to check', () => expect(shipped, isNotEmpty));

  documents.forEach((path, what) {
    test(
      '$what lists exactly the rules that ship',
      tags: [
        // The three root documents live above this package, so this check
        // cannot run from a copy of it taken out of the tree. The package's own
        // README is beside it and needs no tag. See dart_test.yaml.
        if (path.startsWith('../')) 'repo',
      ],
      () {
        final listed = tabulated(path);

        expect(
          shipped.difference(listed),
          isEmpty,
          reason:
              'a rule nobody can find is a rule nobody turns off when it fires '
              'wrongly, and the table is where people look',
        );
        expect(
          listed.difference(shipped),
          isEmpty,
          reason:
              'a row for a rule that does not exist sends a reader to look '
              'for something that was never there',
        );
      },
    );
  });
}
