import 'dart:convert';

final class DoctorPackage {
  const DoctorPackage({
    required this.name,
    required this.version,
    required this.kind,
    this.dependencies = const [],
  });

  final String name;
  final String version;
  final String kind;
  final List<String> dependencies;

  bool get isRuntime => kind == 'root' || kind == 'direct';
}

final class DoctorFile {
  const DoctorFile(this.path, this.content, this.modified);

  final String path;
  final String content;
  final DateTime modified;

  bool get isGenerated => path.endsWith('.g.dart');
}

final class DoctorProject {
  DoctorProject({
    required this.root,
    required Iterable<DoctorPackage> packages,
    this.files = const [],
    this.analysisOptions,
  }) : packages = {for (final package in packages) package.name: package};

  factory DoctorProject.fromPubDeps(
    String json, {
    List<DoctorFile> files = const [],
    String? analysisOptions,
  }) {
    final decoded =
        jsonDecode(json.substring(json.indexOf('{'))) as Map<String, Object?>;
    final packages = decoded['packages']! as List<Object?>;
    return DoctorProject(
      root: decoded['root']! as String,
      packages: [
        for (final entry in packages.cast<Map<String, Object?>>())
          DoctorPackage(
            name: entry['name']! as String,
            version: entry['version']! as String,
            kind: entry['kind']! as String,
            dependencies: [
              ...?(entry['dependencies'] as List<Object?>?)?.cast<String>(),
            ],
          ),
      ],
      files: files,
      analysisOptions: analysisOptions,
    );
  }

  final String root;
  final Map<String, DoctorPackage> packages;
  final List<DoctorFile> files;
  final String? analysisOptions;

  DoctorFile? file(String path) {
    for (final file in files) {
      if (file.path == path) return file;
    }
    return null;
  }

  Iterable<DoctorFile> get sources => files.where((it) => !it.isGenerated);

  String get pub =>
      packages.containsKey('flutter') ? 'flutter pub' : 'dart pub';
}
