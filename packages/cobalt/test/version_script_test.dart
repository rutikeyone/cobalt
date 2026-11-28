@Tags(['repo'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory('../..');
  final packages = Directory('${root.path}/packages')
      .listSync()
      .whereType<Directory>()
      .map((it) => it.uri.pathSegments[it.uri.pathSegments.length - 2])
      .where(
        (name) => File('${root.path}/packages/$name/pubspec.yaml').existsSync(),
      )
      .toList();

  late Directory copy;

  setUp(() {
    copy = Directory.systemTemp.createTempSync('version_script_test');
    Directory('${copy.path}/tool').createSync();
    File(
      '${root.path}/tool/version.py',
    ).copySync('${copy.path}/tool/version.py');
    for (final package in packages) {
      Directory('${copy.path}/packages/$package').createSync(recursive: true);
      for (final file in ['pubspec.yaml', 'CHANGELOG.md']) {
        File(
          '${root.path}/packages/$package/$file',
        ).copySync('${copy.path}/packages/$package/$file');
      }
    }
  });
  tearDown(() => copy.deleteSync(recursive: true));

  final current = File('pubspec.yaml')
      .readAsLinesSync()
      .firstWhere((line) => line.startsWith('version:'))
      .substring('version:'.length)
      .trim();
  final major = int.parse(current.split('-').first.split('.').first);

  ProcessResult bump(String version) =>
      Process.runSync('python3', ['${copy.path}/tool/version.py', version]);

  List<String> linesOf(String package, String file) =>
      File('${copy.path}/packages/$package/$file').readAsLinesSync();

  Map<String, String> internalConstraintsOf(String package) => {
    for (final line in linesOf(package, 'pubspec.yaml'))
      if (RegExp(r'^  (cobalt[a-z_]*): (.+)$').firstMatch(line) case final it?)
        it.group(1)!: it.group(2)!,
  };

  test('a prerelease of the next major is what every internal constraint '
      'asks for', () {
    final next = '${major + 1}.0.0-dev.1';
    File('${copy.path}/GUIDE.md').writeAsStringSync(
      'dependencies:\n  cobalt: ^$major.0.0\n  meta: ^$major.0.0\n',
    );

    final result = bump(next);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    for (final package in packages) {
      expect(linesOf(package, 'pubspec.yaml'), contains('version: $next'));
      expect(
        linesOf(
          package,
          'CHANGELOG.md',
        ).firstWhere((it) => it.startsWith('## ')),
        '## $next',
      );
      for (final MapEntry(:key, :value) in internalConstraintsOf(
        package,
      ).entries) {
        expect(value, '^$next', reason: '$package needs $key');
      }
    }
    expect(result.stdout, contains('GUIDE.md:2: cobalt: ^$major.0.0'));
    expect(result.stdout, isNot(contains('meta')));
    expect(
      File('${copy.path}/GUIDE.md').readAsStringSync(),
      contains('^$major.0.0'),
    );
  });

  test('the release after a prerelease asks for itself', () {
    final release = '${major + 1}.0.0';
    expect(bump('$release-dev.1').exitCode, 0);

    final result = bump(release);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    for (final package in packages) {
      for (final MapEntry(:key, :value) in internalConstraintsOf(
        package,
      ).entries) {
        expect(value, '^$release', reason: '$package needs $key');
      }
    }
  });

  test('a minor after its prerelease keeps the stable constraints', () {
    final prerelease = '${major + 1}.1.0-dev.1';
    final release = '${major + 1}.1.0';
    expect(bump('${major + 1}.0.0').exitCode, 0);
    final stable = {
      for (final package in packages) package: internalConstraintsOf(package),
    };
    expect(bump(prerelease).exitCode, 0);

    final result = bump(release);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    for (final package in packages) {
      expect(internalConstraintsOf(package), {
        ...stable[package]!,
        if (package == 'cobalt_generator') 'cobalt': '^$release',
      });
    }
  });

  test('a minor moves only the generator to the new runtime', () {
    final stable = '${major + 1}.0.0';
    final next = '${major + 1}.1.0';
    expect(bump(stable).exitCode, 0);
    final before = {
      for (final package in packages) package: internalConstraintsOf(package),
    };

    final result = bump(next);

    expect(result.exitCode, 0, reason: '${result.stderr}');
    for (final package in packages) {
      expect(linesOf(package, 'pubspec.yaml'), contains('version: $next'));
      expect(internalConstraintsOf(package), {
        ...before[package]!,
        if (package == 'cobalt_generator') 'cobalt': '^$next',
      });
    }
  });

  test('a changelog that already has the heading keeps one', () {
    final result = bump(current);

    expect(result.exitCode, 0, reason: '${result.stderr}');

    for (final package in packages) {
      expect(
        linesOf(package, 'CHANGELOG.md').where((it) => it == '## $current'),
        hasLength(1),
      );
    }
  });
}
