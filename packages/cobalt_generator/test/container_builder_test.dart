import 'dart:convert';

import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:cobalt_generator/src/builders/container_builder.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

/// One library's IR, as `cobalt_scan` writes it.
String ir(List<CobaltInjectableClass> injectables) => jsonEncode(
  CobaltLibraryDeclarations(
    injectables: injectables,
    bootstrapSteps: const [],
    scopeRoots: const [],
  ).toJson(),
);

CobaltInjectableClass declaredIn(String library, String name) =>
    CobaltInjectableClass(
      type: CobaltTypeRef(name: name, import: library),
      lifetime: CobaltLifetime.lazySingleton,
      constructorParameters: const [],
      properties: const [],
    );

void main() {
  group('the container builder', () {
    test('writes nothing when the package declares nothing', () async {
      await testBuilder(const CobaltContainerBuilder(), {
        'app|lib/plain.dart': 'class Plain {}',
      }, outputs: const {});
    });

    test('writes nothing when every scanned library was empty', () async {
      await testBuilder(const CobaltContainerBuilder(), {
        'app|lib/empty.cobalt.json': ir(const []),
      }, outputs: const {});
    });

    /// The whole reason generation is two-phase.
    ///
    /// build_runner hands a builder one library at a time, so the container —
    /// which is a fact about the package, not about any library — can only be
    /// assembled by a second pass over what the first one left behind.
    test('merges the IR of several libraries into one container', () async {
      await testBuilder(
        const CobaltContainerBuilder(),
        {
          'app|lib/a.cobalt.json': ir([declaredIn('package:app/a.dart', 'A')]),
          'app|lib/b.cobalt.json': ir([declaredIn('package:app/b.dart', 'B')]),
        },
        outputs: {
          'app|lib/cobalt.g.dart': decodedMatches(
            allOf(
              contains('_AFactory'),
              contains('_BFactory'),
              contains(r'class CobaltRoot'),
            ),
          ),
        },
      );
    });

    test('writes into the package it was asked about', () async {
      await testBuilder(
        const CobaltContainerBuilder(),
        {
          'other|lib/a.cobalt.json': ir([
            declaredIn('package:other/a.dart', 'A'),
          ]),
        },
        rootPackage: 'other',
        outputs: {
          'other|lib/cobalt.g.dart': decodedMatches(contains('_AFactory')),
        },
      );
    });
  });
}
