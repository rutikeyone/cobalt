import 'dart:io';

import 'package:cobalt/src/doctor/doctor_checks.dart';
import 'package:cobalt/src/doctor/doctor_project.dart';

const _usage = '''
Checks a project that uses Cobalt for the problems a first build runs into.

Usage: dart run cobalt:doctor [project directory]

Exits with 1 when it finds an error, 2 when it cannot read the project.''';

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help') || args.length > 1) {
    stdout.writeln(_usage);
    return;
  }
  final directory = Directory(args.isEmpty ? '.' : args.single);
  final pubspec = File('${directory.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('No pubspec.yaml in ${directory.absolute.path}.');
    exitCode = 2;
    return;
  }

  final tool = RegExp(r'sdk:\s*flutter\b').hasMatch(pubspec.readAsStringSync())
      ? 'flutter'
      : 'dart';
  final ProcessResult deps;
  try {
    deps = await Process.run(
      tool,
      const ['pub', 'deps', '--json'],
      workingDirectory: directory.path,
      runInShell: true,
    );
  } on ProcessException catch (error) {
    stderr.writeln('Could not run `$tool pub deps`: ${error.message}');
    exitCode = 2;
    return;
  }
  final output = deps.stdout as String;
  if (deps.exitCode != 0 || !output.contains('{')) {
    stderr
      ..writeln('`$tool pub deps --json` failed. Run `$tool pub get` first.')
      ..write(deps.stderr);
    exitCode = 2;
    return;
  }

  final options = File('${directory.path}/analysis_options.yaml');
  final project = DoctorProject.fromPubDeps(
    output,
    files: [..._dartFiles(directory, 'lib'), ..._dartFiles(directory, 'test')],
    analysisOptions: options.existsSync() ? options.readAsStringSync() : null,
  );
  final findings = diagnose(project);
  stdout.write(formatReport(project, findings));
  if (findings.any((it) => it.severity == DoctorSeverity.error)) exitCode = 1;
}

Iterable<DoctorFile> _dartFiles(Directory project, String folder) sync* {
  final root = Directory('${project.path}/$folder');
  if (!root.existsSync()) return;
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.substring(root.path.length + 1);
    yield DoctorFile(
      '$folder/${relative.replaceAll(r'\', '/')}',
      entity.readAsStringSync(),
      entity.lastModifiedSync(),
    );
  }
}
