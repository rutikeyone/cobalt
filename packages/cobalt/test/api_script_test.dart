@Tags(['repo'])
library;

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
}
