@Tags(['repo'])
library;

import 'dart:io';

import 'package:test/test.dart';

/// Every root document comes in four languages, and links to its siblings.
///
/// Splitting the README into a description and a guide, and then splitting the
/// guide by mode, took the root documents from three files to twelve and
/// multiplied the links between them by more than that. Whether a translation
/// still says what the English says is not checkable by machine — that stays a
/// line in the RELEASING checklist. What is checkable is that it exists and
/// that its links land somewhere, which are the two ways this actually goes
/// wrong.
///
/// Like the package and rule guards, it reads files above its own package,
/// because the check belongs where the thing being checked lives and there is
/// no repository-wide suite to put it in.
void main() {
  final root = Directory('../..');

  const families = {'README', 'GUIDE_MANUAL', 'GUIDE_CODEGEN', 'MIGRATION'};

  String path(String stem) => '${root.path}/$stem';

  List<String> translationsOf(String family) => [
    '$family.md',
    '$family.ru.md',
    '$family.zh-CN.md',
    '$family.ko.md',
  ];

  group('every root document exists in four languages', () {
    for (final family in families) {
      for (final name in translationsOf(family)) {
        test(name, () {
          final file = File(path(name));
          expect(file.existsSync(), isTrue, reason: '$name is missing');
          expect(
            file.readAsStringSync().trim(),
            isNotEmpty,
            reason: 'an empty $name passes CI and helps nobody',
          );
        });
      }
    }
  });

  group('every translation offers the other three', () {
    for (final family in families) {
      final switcher =
          '  <a href="$family.md">English</a> · '
          '<a href="$family.ru.md">Русский</a> · '
          '<a href="$family.zh-CN.md">中文</a> · '
          '<a href="$family.ko.md">한국어</a>';

      for (final name in translationsOf(family)) {
        test(name, () {
          /// Near the top rather than on line one: a banner and a badge row
          /// come first in the READMEs. Twenty lines sounds generous and is
          /// not — centred HTML costs three source lines per visual row, so
          /// that window is still the first screenful. What matters is that
          /// the switcher is there, is reachable without scrolling, and is
          /// byte-identical in all four; a differing one makes a language a
          /// dead end.
          expect(
            File(path(name)).readAsLinesSync().take(20),
            contains(switcher),
            reason:
                'the switcher is the only way a reader moves between '
                'languages, so it has to be identical in all four and near '
                'enough to the top to be seen',
          );
        });
      }
    }
  });

  group('every relative link resolves', () {
    /// The banner keeps its alpha channel.
    ///
    /// The card is a rounded rectangle, so without one its four corners are
    /// filled with whatever the renderer painted the page — white, in
    /// practice, which is invisible while you look at it on a light
    /// background and glaring on GitHub's dark one. Regenerating it with the
    /// flag left off has already happened once; `tool/banner.sh` exists so it
    /// does not happen from memory, and this notices if it does.
    test('the banner is transparent where it is round', () {
      final header = File(
        path('assets/banner.png'),
      ).readAsBytesSync().sublist(0, 26);

      expect(header.sublist(0, 8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ], reason: 'not a PNG at all');
      expect(
        header[25],
        6,
        reason:
            'colour type 6 is RGBA; 2 is RGB, which is what Chrome writes '
            'when --default-background-color=00000000 is left off',
      );
    });

    /// Markdown links that point at a path in this repository.
    ///
    /// All three spellings. The language switcher is centred HTML, so a regex
    /// that only knew markdown would stop checking the very links that matter
    /// most — the ones between translations — and `src` covers the banner,
    /// which is the one image a missing file would show as a broken box on
    /// the landing page. External URLs are somebody else's to
    /// keep alive; an anchor is dropped because headings are checked by
    /// reading, not by regex.
    Iterable<String> linksIn(String name) =>
        RegExp(r'\]\(([^)\s]+)\)|(?:href|src)="([^"]+)"')
            .allMatches(File(path(name)).readAsStringSync())
            .map((it) => it.group(1) ?? it.group(2)!)
            .where(
              (target) => !target.startsWith('http') && !target.startsWith('#'),
            )
            .map((target) => target.split('#').first)
            .where((target) => target.isNotEmpty);

    for (final family in families) {
      for (final name in translationsOf(family)) {
        test(name, () {
          final broken = linksIn(name)
              .where(
                (target) =>
                    !File(path(target)).existsSync() &&
                    !Directory(path(target)).existsSync(),
              )
              .toSet();

          expect(
            broken,
            isEmpty,
            reason:
                'a link to a document that moved sends the reader nowhere, '
                'and these documents link to each other constantly',
          );
        });
      }
    }
  });
}
