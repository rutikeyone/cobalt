@Tags(['repo'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory stubs;

  setUp(() => stubs = Directory.systemTemp.createTempSync('release_gate_test'));
  tearDown(() => stubs.deleteSync(recursive: true));

  void stub(String name, String body) {
    final file = File('${stubs.path}/$name')
      ..writeAsStringSync('#!/bin/sh\n$body\n');
    Process.runSync('chmod', ['+x', file.path]);
  }

  ProcessResult runGate({
    required List<String> branches,
    required List<String> containing,
    required List<String> runs,
    bool ghFails = false,
  }) {
    stub('git', '''
case "\$1" in
  rev-parse) for b in ${branches.join(' ')}; do [ "\$4" = "origin/\$b" ] && exit 0; done ;;
  merge-base) for b in ${containing.join(' ')}; do [ "\$4" = "origin/\$b" ] && exit 0; done ;;
esac
exit 1''');
    stub(
      'gh',
      [for (final run in runs) "echo '$run'", if (ghFails) 'exit 1'].join('\n'),
    );
    return Process.runSync(
      'sh',
      ['../../tool/release_gate.sh'],
      environment: {
        'PATH': '${stubs.path}:${Platform.environment['PATH']}',
        'GITHUB_SHA': 'c0ffee',
        'RELEASE_GATE_MINUTES': '0',
      },
    );
  }

  test('a green commit on main passes', () {
    final result = runGate(
      branches: ['main'],
      containing: ['main'],
      runs: ['completed success'],
    );

    expect(result.exitCode, 0, reason: '${result.stdout}');
  });

  test('a green commit on 1.x passes', () {
    final result = runGate(
      branches: ['main', '1.x'],
      containing: ['1.x'],
      runs: ['completed success'],
    );

    expect(result.exitCode, 0, reason: '${result.stdout}');
  });

  test('a commit on neither branch fails before CI is asked', () {
    final result = runGate(
      branches: ['main'],
      containing: [],
      runs: ['completed success'],
    );

    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('on neither origin/main nor origin/1.x'));
  });

  test('a red CI fails', () {
    final result = runGate(
      branches: ['main'],
      containing: ['main'],
      runs: ['completed failure'],
    );

    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('ci failed'));
  });

  test('a CI that has not finished by the deadline fails', () {
    final result = runGate(
      branches: ['main'],
      containing: ['main'],
      runs: ['in_progress '],
    );

    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('did not finish green'));
  });

  test('a commit CI never ran on fails at the deadline', () {
    final result = runGate(branches: ['main'], containing: ['main'], runs: []);

    expect(result.exitCode, isNot(0));
    expect(result.stdout, contains('ci has no push run for c0ffee'));
    expect(result.stdout, contains('did not finish green'));
  });

  test('gh failing fails the gate instead of waiting', () {
    final result = runGate(
      branches: ['main'],
      containing: ['main'],
      runs: [],
      ghFails: true,
    );

    expect(result.exitCode, isNot(0));
    expect(result.stdout, isNot(contains('has not finished')));
    expect(result.stdout, isNot(contains('no push run')));
    expect(result.stdout, isNot(contains('did not finish green')));
    expect(result.stdout, contains('gh could not list ci runs for c0ffee'));
  });
}
