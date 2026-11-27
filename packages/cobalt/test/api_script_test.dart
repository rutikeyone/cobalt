@Tags(['repo'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory stubs;

  setUp(() => stubs = Directory.systemTemp.createTempSync('api_script_test'));
  tearDown(() => stubs.deleteSync(recursive: true));

  void stub(String name, String body) {
    final file = File('${stubs.path}/$name')
      ..writeAsStringSync('#!/bin/sh\n$body\n');
    Process.runSync('chmod', ['+x', file.path]);
  }

  ProcessResult runWithCurl(String curl) {
    stub('curl', curl);
    stub('dart-apitool', 'exit 0');
    return Process.runSync(
      'sh',
      ['../../tool/api.sh', 'cobalt'],
      environment: {'PATH': '${stubs.path}:${Platform.environment['PATH']}'},
    );
  }

  ProcessResult runWithPublished(
    List<Map<String, Object>> versions, {
    required String latest,
  }) {
    File('${stubs.path}/answer.json').writeAsStringSync(
      jsonEncode({
        'name': 'cobalt',
        'latest': {'version': latest},
        'versions': versions,
      }),
    );
    return runWithCurl('''
while [ \$# -gt 0 ]; do
  [ "\$1" = -o ] && out=\$2
  shift
done
cp "${stubs.path}/answer.json" "\$out"
printf 200''');
  }

  final major = int.parse(
    File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((line) => line.startsWith('version:'))
        .substring('version:'.length)
        .trim()
        .split('.')
        .first,
  );

  test('a network failure fails the check', () {
    final result = runWithCurl('exit 6');

    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('FAILED: pub.dev not reachable'));
  });

  test('a package pub.dev does not know is skipped', () {
    final result = runWithCurl('printf 404');

    expect(result.exitCode, 0);
    expect(result.stdout, contains('not on pub.dev yet'));
  });

  test('a patch is compared with the newest release of its own major', () {
    final result = runWithPublished([
      {'version': '$major.9.0'},
      {'version': '$major.10.0'},
      {'version': '$major.999.0', 'retracted': true},
      {'version': '${major + 1}.0.0'},
    ], latest: '${major + 1}.0.0');

    expect(result.exitCode, 0);
    expect(result.stdout, contains('checkout against $major.10.0 on pub.dev'));
  });

  test('without a stable release of its own major, latest is the base', () {
    final result = runWithPublished([
      {'version': '${major + 1}.0.0'},
      {'version': '$major.999.0-dev.1'},
    ], latest: '${major + 1}.0.0');

    expect(result.exitCode, 0);
    expect(
      result.stdout,
      contains('checkout against ${major + 1}.0.0 on pub.dev'),
    );
  });
}
