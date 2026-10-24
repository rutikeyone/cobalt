import 'package:cobalt/src/doctor/doctor_checks.dart';
import 'package:cobalt/src/doctor/doctor_project.dart';
import 'package:test/test.dart';

DoctorPackage package(
  String name, {
  String version = '1.8.0',
  String kind = 'direct',
  List<String> dependencies = const [],
}) => DoctorPackage(
  name: name,
  version: version,
  kind: kind,
  dependencies: dependencies,
);

final _earlier = DateTime(2026, 10, 1);
final _later = DateTime(2026, 10, 2);

DoctorFile file(String path, String content, [DateTime? modified]) =>
    DoctorFile(path, content, modified ?? _earlier);

const _lintOn = 'plugins:\n  cobalt_lint: ^1.8.0\n';

DoctorProject project({
  List<DoctorPackage> packages = const [],
  List<DoctorFile> files = const [],
  String? analysisOptions = _lintOn,
}) => DoctorProject(
  root: 'my_app',
  packages: [
    package('my_app', version: '1.0.0+1', kind: 'root'),
    package('cobalt'),
    ...packages,
  ],
  files: files,
  analysisOptions: analysisOptions,
);

final _codegen = [
  package('cobalt_generator', kind: 'dev', dependencies: ['analyzer']),
  package('build_runner', version: '2.15.0', kind: 'dev'),
  package('analyzer', version: '12.1.0', kind: 'transitive'),
];

final _annotated = file('lib/cart.dart', '@cobaltInject\nclass Cart {}\n');

void main() {
  test('reads what pub deps --json prints', () {
    const json = '''
{
  "root": "my_app",
  "packages": [
    {
      "name": "my_app",
      "version": "1.0.0+1",
      "kind": "root",
      "source": "root",
      "dependencies": ["cobalt", "flutter", "cobalt_generator"],
      "directDependencies": ["cobalt", "flutter"],
      "devDependencies": ["cobalt_generator"]
    },
    {
      "name": "cobalt_generator",
      "version": "1.8.0",
      "kind": "dev",
      "source": "hosted",
      "dependencies": ["analyzer"],
      "directDependencies": ["analyzer"]
    },
    {
      "name": "flutter",
      "version": "0.0.0",
      "kind": "direct",
      "source": "sdk",
      "dependencies": []
    }
  ],
  "sdks": [{"name": "Dart", "version": "3.10.8"}],
  "executables": ["build_runner"]
}
''';
    final project = DoctorProject.fromPubDeps(json);

    expect(project.root, 'my_app');
    expect(project.packages['cobalt_generator']!.kind, 'dev');
    expect(project.packages['cobalt_generator']!.dependencies, ['analyzer']);
    expect(project.pub, 'flutter pub');
  });

  group('versions', () {
    test('one version is quiet', () {
      expect(
        checkVersions(project(packages: [package('cobalt_flutter')])),
        isEmpty,
      );
    });

    test('a generator newer than the runtime is an error', () {
      final findings = checkVersions(
        DoctorProject(
          root: 'my_app',
          packages: [
            package('cobalt', version: '1.7.0'),
            package('cobalt_generator', kind: 'dev'),
          ],
        ),
      ).toList();

      expect(findings.single.severity, DoctorSeverity.error);
      expect(findings.single.summary, contains('cobalt_generator 1.8.0'));
      expect(findings.single.details.single, contains('upgrade cobalt'));
    });

    test('a generator one patch ahead is only drift', () {
      final findings = checkVersions(
        project(packages: [package('cobalt_generator', version: '1.8.1')]),
      ).toList();

      expect(findings.single.severity, DoctorSeverity.note);
    });

    test('drift the constraints allow is a note naming each', () {
      final findings = checkVersions(
        project(packages: [package('cobalt_annotations', version: '1.7.0')]),
      ).toList();

      expect(findings.single.severity, DoctorSeverity.note);
      expect(findings.single.details.first, contains('cobalt 1.8.0'));
      expect(
        findings.single.details.first,
        contains('cobalt_annotations 1.7.0'),
      );
    });
  });

  group('the generator', () {
    test('annotations without it are an error', () {
      final findings = checkGenerator(project(files: [_annotated])).toList();

      expect(findings.single.severity, DoctorSeverity.error);
      expect(findings.single.details.first, contains('lib/cart.dart'));
    });

    test('it without build_runner is an error', () {
      final findings = checkGenerator(
        project(packages: [_codegen.first], files: [_annotated]),
      ).toList();

      expect(findings.single.summary, contains('build_runner'));
    });

    test('Manual Mode needs neither', () {
      expect(
        checkGenerator(
          project(files: [file('lib/main.dart', 'void main() {}')]),
        ),
        isEmpty,
      );
    });
  });

  group('the analyzer', () {
    final freezed = package(
      'freezed',
      version: '2.5.8',
      kind: 'dev',
      dependencies: ['analyzer'],
    );
    final old = package('analyzer', version: '7.7.1', kind: 'transitive');

    test('one too old for the generator names who holds it', () {
      final findings = checkAnalyzer(
        project(packages: [freezed, old]),
      ).toList();

      expect(findings.single.severity, DoctorSeverity.note);
      expect(findings.single.summary, contains('too old'));
      expect(findings.single.details.first, contains('freezed 2.5.8'));
      expect(findings.single.details.first, contains('>=10.0.1 <15.0.0'));
    });

    test('is an error once annotations need the generator', () {
      final findings = checkAnalyzer(
        project(packages: [freezed, old], files: [_annotated]),
      ).toList();

      expect(findings.single.severity, DoctorSeverity.error);
    });

    test('one too new says so', () {
      final findings = checkAnalyzer(
        project(packages: [package('analyzer', version: '15.0.0')]),
      ).toList();

      expect(findings.single.summary, contains('too new'));
    });

    test('one in range is quiet', () {
      expect(
        checkAnalyzer(
          project(packages: [package('analyzer', version: '12.1.0')]),
        ),
        isEmpty,
      );
    });

    test('once the generator resolved there is nothing to say', () {
      expect(checkAnalyzer(project(packages: _codegen)), isEmpty);
    });
  });

  group('the generated file', () {
    test('missing is an error', () {
      final findings = checkGeneratedFile(
        project(packages: _codegen, files: [_annotated]),
      ).toList();

      expect(findings.single.severity, DoctorSeverity.error);
      expect(findings.single.summary, contains('lib/cobalt.g.dart'));
    });

    test('older than an annotated file is a warning', () {
      final findings = checkGeneratedFile(
        project(
          packages: _codegen,
          files: [
            file('lib/cart.dart', '@cobaltInject\nclass Cart {}\n', _later),
            file('lib/cobalt.g.dart', '', _earlier),
          ],
        ),
      ).toList();

      expect(findings.single.severity, DoctorSeverity.warning);
      expect(findings.single.summary, contains('lib/cart.dart'));
    });

    test('newer than every annotated file is quiet', () {
      expect(
        checkGeneratedFile(
          project(
            packages: _codegen,
            files: [_annotated, file('lib/cobalt.g.dart', '', _later)],
          ),
        ),
        isEmpty,
      );
    });

    test('with cobalt only as a dev dependency is an error', () {
      final findings = checkGeneratedFile(
        DoctorProject(
          root: 'my_app',
          packages: [
            package('cobalt', kind: 'dev'),
            ..._codegen,
          ],
          files: [_annotated, file('lib/cobalt.g.dart', '', _later)],
        ),
      ).toList();

      expect(findings.single.summary, 'cobalt is not in dependencies');
    });
  });

  group('the template test', () {
    final template = file(
      'test/widget_test.dart',
      'void main() { testWidgets((t) => t.pumpWidget(const MyApp())); }',
    );

    test('pumping a MyApp that lib/ dropped is a warning', () {
      final findings = checkTemplateTest(
        project(files: [template, file('lib/main.dart', 'class App {}')]),
      ).toList();

      expect(findings.single.severity, DoctorSeverity.warning);
    });

    test('is fine while lib/ still declares MyApp', () {
      expect(
        checkTemplateTest(
          project(files: [template, file('lib/main.dart', 'class MyApp {}')]),
        ),
        isEmpty,
      );
    });
  });

  group('renamed names', () {
    test('an old name in the code is a warning with the new one', () {
      final findings = checkRenamedNames(
        project(files: [file('lib/main.dart', r'await $startCobalt();')]),
      ).toList();

      expect(findings.single.summary, r'$startCobalt is now startCobalt');
      expect(findings.single.details.single, contains('lib/main.dart'));
    });

    test('the generated file declaring it does not count', () {
      expect(
        checkRenamedNames(
          project(
            files: [file('lib/cobalt.g.dart', r'Future<void> $startCobalt()')],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('cobalt_lint', () {
    test('enabled under plugins is quiet', () {
      expect(
        checkLint(
          project(analysisOptions: 'include: x.yaml\n\nplugins:\n$_lintOn'),
        ),
        isEmpty,
      );
      expect(
        checkLint(
          project(
            analysisOptions:
                'plugins:\n  other: ^1.0.0\n  # note\n  cobalt_lint: ^1.8.0',
          ),
        ),
        isEmpty,
      );
    });

    test('missing is a note with the lines to add', () {
      final findings = checkLint(project(analysisOptions: null)).toList();

      expect(findings.single.severity, DoctorSeverity.note);
      expect(findings.single.details.last, '  cobalt_lint: ^1.8.0');
    });

    test('under another section is not enabled', () {
      expect(
        checkLint(
          project(
            analysisOptions:
                'analyzer:\n  plugins:\n    - cobalt_lint\nlinter:\n  rules: []\n',
          ),
        ),
        hasLength(1),
      );
    });
  });

  group('the report', () {
    test('of a healthy project says so', () {
      final healthy = project(
        packages: _codegen,
        files: [_annotated, file('lib/cobalt.g.dart', '', _later)],
      );

      expect(diagnose(healthy), isEmpty);
      expect(
        formatReport(healthy, const []),
        'Cobalt doctor: my_app (cobalt 1.8.0)\n\nNo problems found.\n',
      );
    });

    test('lists each finding and counts them', () {
      final report = formatReport(project(), const [
        DoctorFinding(DoctorSeverity.error, 'broken', ['why']),
        DoctorFinding(DoctorSeverity.note, 'maybe'),
      ]);

      expect(report, contains('error    broken\n         why\n'));
      expect(report, contains('note     maybe\n'));
      expect(report, endsWith('1 error, 1 note\n'));
    });
  });
}
