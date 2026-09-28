import 'dart:io';

import 'package:cobalt_generator/builder.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:package_config/package_config.dart';
import 'package:test/test.dart';

import 'builder_support.dart';

const _pkg = 'cobalt_generator';

void main() {
  final builder = cobaltPropertyInjectionBuilder(const BuilderOptions({}));
  late PackageConfig packages;
  late Map<String, Object> deps;

  setUpAll(() async {
    packages = (await findPackageConfig(Directory.current))!;
    deps = sourcesOf(packages, 'cobalt_annotations')
      ..addAll(sourcesOf(packages, 'meta'));
  });

  group('the property injection builder', () {
    /// Most annotated classes take their dependencies through the
    /// constructor. Emitting an empty part for them would make `part` a
    /// requirement of `@CobaltInject` rather than of `@injected`.
    test('writes nothing for a class with no injected fields', () async {
      await testBuilder(
        builder,
        {
          ...deps,
          '$_pkg|lib/plain.dart': '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

@cobaltInject
class Api {
  Api(this.logger);
  final Object logger;
}
''',
        },
        packageConfig: packages,
        generateFor: {'$_pkg|lib/plain.dart'},
        outputs: const {},
      );
    });

    test('emits a mixin that can assign a private field', () async {
      await testBuilder(
        builder,
        {
          ...deps,
          '$_pkg|lib/controller.dart': '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

class Store {}

@cobaltTransient
class Controller {
  Controller();

  @injected
  late final Store _store;
}
''',
        },
        packageConfig: packages,
        generateFor: {'$_pkg|lib/controller.dart'},
        outputs: {
          '$_pkg|lib/controller.cobalt.g.part': decodedMatches(
            allOf(
              contains(r'mixin _$Controller implements CobaltInjectable'),
              contains('set _store('),
              contains('void onInject(CobaltResolver resolver)'),
            ),
          ),
        },
      );
    });

    /// The hole this generator was rewritten to close.
    ///
    /// `@CobaltInit` makes a class injectable — the container registers it as
    /// an async singleton — but the mixin used to be emitted only for
    /// `@CobaltInject`. Such a class was registered, built, and left with its
    /// fields unassigned, failing with a LateInitializationError at first use,
    /// while the lint told you to mix in something nothing would write.
    test(
      'emits for an @CobaltInit class too, not only @CobaltInject',
      () async {
        await testBuilder(
          builder,
          {
            ...deps,
            '$_pkg|lib/warmer.dart': '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

class Config {}

@CobaltInit()
class Warmer {
  Warmer();

  @injected
  late final Config _config;

  Future<void> init() async {}
}
''',
          },
          packageConfig: packages,
          generateFor: {'$_pkg|lib/warmer.dart'},
          outputs: {
            '$_pkg|lib/warmer.cobalt.g.part': decodedMatches(
              allOf(
                contains(r'mixin _$Warmer implements CobaltInjectable'),
                contains('set _config('),
              ),
            ),
          },
        );
      },
    );

    test('emits for an @CobaltDecorates class with injected fields', () async {
      await testBuilder(
        builder,
        {
          ...deps,
          '$_pkg|lib/logged.dart': '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

abstract interface class Api {}

class Logger {}

@CobaltDecorates(Api)
class LoggedApi implements Api {
  LoggedApi(this.inner);

  final Api inner;

  @injected
  late final Logger _log;
}
''',
        },
        packageConfig: packages,
        generateFor: {'$_pkg|lib/logged.dart'},
        outputs: {
          '$_pkg|lib/logged.cobalt.g.part': decodedMatches(
            allOf(
              contains(r'mixin _$LoggedApi implements CobaltInjectable'),
              contains('set _log('),
            ),
          ),
        },
      );
    });

    test('emits one mixin per class in a library that has several', () async {
      await testBuilder(
        builder,
        {
          ...deps,
          '$_pkg|lib/pair.dart': '''
import 'package:cobalt_annotations/cobalt_annotations.dart';

class Store {}

@cobaltInject
class First {
  First();

  @injected
  late final Store _store;
}

@cobaltTransient
class Second {
  Second();

  @injected
  late final Store _store;
}
''',
        },
        packageConfig: packages,
        generateFor: {'$_pkg|lib/pair.dart'},
        outputs: {
          '$_pkg|lib/pair.cobalt.g.part': decodedMatches(
            allOf(contains(r'mixin _$First'), contains(r'mixin _$Second')),
          ),
        },
      );
    });
  });
}
