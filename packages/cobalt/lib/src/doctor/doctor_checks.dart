import 'package:cobalt/src/doctor/doctor_project.dart';

enum DoctorSeverity { error, warning, note }

final class DoctorFinding {
  const DoctorFinding(this.severity, this.summary, [this.details = const []]);

  final DoctorSeverity severity;
  final String summary;
  final List<String> details;
}

const cobaltPackages = {
  'cobalt',
  'cobalt_analyzer',
  'cobalt_annotations',
  'cobalt_bloc',
  'cobalt_flutter',
  'cobalt_generator',
  'cobalt_go_router',
  'cobalt_inspector',
  'cobalt_lint',
  'cobalt_logger',
  'cobalt_logging',
  'cobalt_talker',
  'cobalt_talker_flutter',
  'cobalt_test',
  'cobalt_test_flutter',
};

const generatorAnalyzer = (min: '10.0.1', max: '15.0.0');

const renamedGeneratedNames = {
  r'$CobaltRootScope': 'CobaltRoot',
  r'$startCobalt': 'startCobalt',
  r'$cobaltRootScopeName': 'cobaltRootScopeName',
  r'$cobaltBootstrap': 'cobaltBootstrapSteps',
};

const _generated = 'lib/cobalt.g.dart';

final _renamedArgs = RegExp(r'\$([A-Z]\w*Args)\b');

final _annotation = RegExp(
  r'@(cobaltInject|cobaltSingleton|cobaltTransient|cobaltModule|'
  r'cobaltBootstrap|CobaltInject|CobaltChildScope|CobaltScopeRoot|'
  r'CobaltModule|CobaltBootstrap|CobaltDecorates)\b',
);

final _lintPlugin = RegExp(
  r'^plugins:[^\n]*\n(?:[ \t]*(?:#[^\n]*)?\n|[ \t]+[^\n]*\n)*?[ \t]+cobalt_lint[ \t]*:',
  multiLine: true,
);

List<DoctorFinding> diagnose(DoctorProject project) => [
  ...checkVersions(project),
  ...checkGenerator(project),
  ...checkAnalyzer(project),
  ...checkGeneratedFile(project),
  ...checkTemplateTest(project),
  ...checkRenamedNames(project),
  ...checkLint(project),
];

Iterable<DoctorFinding> checkVersions(DoctorProject project) sync* {
  final cobalt = project.packages['cobalt'];
  final generator = project.packages['cobalt_generator'];
  if (cobalt != null &&
      generator != null &&
      _compare(_minor(generator.version), _minor(cobalt.version)) > 0) {
    yield DoctorFinding(
      DoctorSeverity.error,
      'cobalt_generator ${generator.version} writes code for a newer cobalt '
      'than ${cobalt.version}',
      [
        'Nothing in pub ties the two together, and the generated code uses '
            'what cobalt ${_minor(generator.version)} added. Run '
            '`${project.pub} upgrade cobalt`.',
      ],
    );
    return;
  }
  final present = [for (final name in cobaltPackages) ?project.packages[name]];
  if (present.map((it) => it.version).toSet().length < 2) return;
  yield DoctorFinding(
    DoctorSeverity.note,
    'Cobalt packages are on different versions',
    [
      present.map((it) => '${it.name} ${it.version}').join(', '),
      'Their constraints allow it, but they are released together; '
          '`${project.pub} upgrade` brings them to one version.',
    ],
  );
}

Iterable<DoctorFinding> checkGenerator(DoctorProject project) sync* {
  final annotated = _annotated(project);
  if (annotated.isEmpty) return;
  if (!project.packages.containsKey('cobalt_generator')) {
    yield DoctorFinding(
      DoctorSeverity.error,
      'Cobalt annotations are used, but cobalt_generator is not a dependency',
      [
        'Found in ${_paths(annotated)}.',
        'Add it: `${project.pub} add dev:cobalt_generator dev:build_runner`, '
            'or remove the annotations to stay in Manual Mode.',
      ],
    );
  } else if (!project.packages.containsKey('build_runner')) {
    yield DoctorFinding(
      DoctorSeverity.error,
      'cobalt_generator is a dependency, but build_runner is not',
      ['The generator runs under it: `${project.pub} add dev:build_runner`.'],
    );
  }
}

Iterable<DoctorFinding> checkAnalyzer(DoctorProject project) sync* {
  final analyzer = project.packages['analyzer'];
  if (analyzer == null || project.packages.containsKey('cobalt_generator')) {
    return;
  }
  final (:min, :max) = generatorAnalyzer;
  final tooOld = _compare(analyzer.version, min) < 0;
  if (!tooOld && _compare(analyzer.version, max) < 0) return;
  final holders = [
    for (final package in project.packages.values)
      if (package.dependencies.contains('analyzer'))
        package.kind == 'root'
            ? package.name
            : '${package.name} ${package.version}',
  ];
  final cobalt = project.packages['cobalt']?.version;
  yield DoctorFinding(
    _annotated(project).isEmpty ? DoctorSeverity.note : DoctorSeverity.error,
    'analyzer ${analyzer.version} is too ${tooOld ? 'old' : 'new'} for '
    'cobalt_generator',
    [
      'cobalt_generator${cobalt == null ? '' : ' $cobalt'} needs analyzer '
          '>=$min <$max. Held at ${analyzer.version} by '
          '${holders.isEmpty ? 'the lock file' : holders.join(', ')}.',
      'Upgrade those first to use the generator. Manual Mode needs none.',
    ],
  );
}

Iterable<DoctorFinding> checkGeneratedFile(DoctorProject project) sync* {
  final generated = project.file(_generated);
  final annotated = _annotated(project);
  if (generated == null) {
    if (annotated.isNotEmpty &&
        project.packages.containsKey('cobalt_generator')) {
      yield const DoctorFinding(
        DoctorSeverity.error,
        '$_generated has not been generated',
        [
          'Run `dart run build_runner build`, and again after changing an '
              'annotation; `dart run build_runner watch` keeps it current.',
        ],
      );
    }
    return;
  }
  final newest = annotated.fold<DoctorFile?>(
    null,
    (newest, file) => newest == null || file.modified.isAfter(newest.modified)
        ? file
        : newest,
  );
  if (newest != null && newest.modified.isAfter(generated.modified)) {
    yield DoctorFinding(
      DoctorSeverity.warning,
      '$_generated is older than ${newest.path}',
      [
        'If an annotation changed since the last build, run '
            '`dart run build_runner build`.',
      ],
    );
  }
  final cobalt = project.packages['cobalt'];
  if (cobalt != null && !cobalt.isRuntime) {
    yield DoctorFinding(DoctorSeverity.error, 'cobalt is not in dependencies', [
      '$_generated imports package:cobalt, so the app has to depend on '
          'it: `${project.pub} add cobalt`.',
    ]);
  }
}

Iterable<DoctorFinding> checkTemplateTest(DoctorProject project) sync* {
  final test = project.file('test/widget_test.dart');
  if (test == null || !RegExp(r'\bMyApp\b').hasMatch(test.content)) return;
  final declared = project.sources.any(
    (it) =>
        it.path.startsWith('lib/') &&
        RegExp(r'class\s+MyApp\b').hasMatch(it.content),
  );
  if (declared) return;
  yield const DoctorFinding(
    DoctorSeverity.warning,
    'test/widget_test.dart still tests the app from flutter create',
    [
      'It pumps MyApp, which lib/ no longer declares. Replace it with the '
          'test from the Quick start: '
          'https://github.com/rutikeyone/cobalt#quick-start',
    ],
  );
}

Iterable<DoctorFinding> checkRenamedNames(DoctorProject project) sync* {
  final renamed = {
    ...renamedGeneratedNames,
    for (final file in project.sources)
      for (final match in _renamedArgs.allMatches(file.content))
        match.group(0)!: match.group(1)!,
  };
  for (final MapEntry(key: old, value: current) in renamed.entries) {
    final pattern = RegExp('${RegExp.escape(old)}\\b');
    final users = [
      for (final file in project.sources)
        if (pattern.hasMatch(file.content)) file,
    ];
    if (users.isEmpty) continue;
    yield DoctorFinding(DoctorSeverity.warning, '$old is now $current', [
      'The old name goes away in 2.0. Used in ${_paths(users)}.',
    ]);
  }
}

Iterable<DoctorFinding> checkLint(DoctorProject project) sync* {
  final options = project.analysisOptions;
  if (options != null && _lintPlugin.hasMatch('$options\n')) return;
  final version = project.packages['cobalt']?.version;
  yield DoctorFinding(DoctorSeverity.note, 'cobalt_lint is not enabled', [
    'It reports Cobalt mistakes in the editor and fixes most of them. In '
        'analysis_options.yaml:',
    'plugins:',
    '  cobalt_lint: ^${version ?? '1.0.0'}',
  ]);
}

String formatReport(DoctorProject project, List<DoctorFinding> findings) {
  final out = StringBuffer();
  final cobalt = project.packages['cobalt']?.version;
  out
    ..writeln(
      'Cobalt doctor: ${project.root}'
      '${cobalt == null ? '' : ' (cobalt $cobalt)'}',
    )
    ..writeln();
  if (findings.isEmpty) {
    out.writeln('No problems found.');
    return out.toString();
  }
  for (final finding in findings) {
    out.writeln('${finding.severity.name.padRight(9)}${finding.summary}');
    for (final line in finding.details) {
      out.writeln('${' ' * 9}$line');
    }
    out.writeln();
  }
  out.writeln(
    [
      for (final severity in DoctorSeverity.values)
        if (findings.where((it) => it.severity == severity).length
            case final count when count > 0)
          '$count ${severity.name}${count == 1 ? '' : 's'}',
    ].join(', '),
  );
  return out.toString();
}

List<DoctorFile> _annotated(DoctorProject project) => [
  for (final file in project.sources)
    if (file.path.startsWith('lib/') && _annotation.hasMatch(file.content))
      file,
];

String _paths(List<DoctorFile> files) {
  final shown = files.take(3).map((it) => it.path).join(', ');
  return files.length > 3 ? '$shown and ${files.length - 3} more' : shown;
}

String _minor(String version) =>
    '${version.split(RegExp('[-+]')).first.split('.').take(2).join('.')}.0';

int _compare(String a, String b) {
  List<int> parts(String version) => [
    for (final part in version.split(RegExp('[-+]')).first.split('.'))
      int.tryParse(part) ?? 0,
  ];
  final left = parts(a);
  final right = parts(b);
  for (var i = 0; i < 3; i++) {
    final difference =
        (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
    if (difference != 0) return difference;
  }
  return 0;
}
