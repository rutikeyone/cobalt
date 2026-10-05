import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher rejects(Object matcher) => throwsA(
  isA<CobaltParseError>().having((e) => e.message, 'message', matcher),
);

void main() {
  const parser = CobaltBootstrapParser();

  Future<CobaltBootstrapStepClass> parse(String source) async =>
      parser.parseClass(await classNamed('Seed', source));

  group('what it reads', () {
    test('the class, its order and environments', () async {
      final step = await parse('''
@CobaltBootstrap(order: -10)
@CobaltEnvironment.dev
class Seed implements CobaltBootstrapStep {
  @override
  String get name => 'seed';
  @override
  void run() {}
}
''');

      expect(step.type.name, 'Seed');
      expect(step.order, -10);
      expect(step.environments, {'dev'});
    });

    test('order defaults to zero', () async {
      final step = await parse('''
@cobaltBootstrap
class Seed implements CobaltBootstrapStep {
  @override
  String get name => 'seed';
  @override
  void run() {}
}
''');

      expect(step.order, 0);
      expect(step.environments, isEmpty);
    });

    test('a run() inherited from a supertype counts', () async {
      final step = await parse('''
abstract class Base implements CobaltBootstrapStep {
  @override
  void run() {}
}

@cobaltBootstrap
class Seed extends Base {
  @override
  String get name => 'seed';
}
''');

      expect(step.type.name, 'Seed');
    });
  });

  group('what it refuses', () {
    test('an abstract class', () async {
      await expectLater(
        parse('''
@cobaltBootstrap
abstract class Seed implements CobaltBootstrapStep {}
'''),
        rejects(contains('abstract and cannot be a bootstrap step')),
      );
    });

    test('a class with no public generative constructor', () async {
      await expectLater(
        parse('''
@cobaltBootstrap
class Seed implements CobaltBootstrapStep {
  Seed._();
  factory Seed.create() => Seed._();
  @override
  String get name => 'seed';
  @override
  void run() {}
}
'''),
        rejects(contains('no public generative constructor')),
      );
    });

    test('a constructor with required parameters', () async {
      await expectLater(
        parse('''
class Logger {}

@cobaltBootstrap
class Seed implements CobaltBootstrapStep {
  Seed(this.log);
  final Logger log;
  @override
  String get name => 'seed';
  @override
  void run() {}
}
'''),
        rejects(contains('must have a constructor without required')),
      );
    });

    test('a class with no run() method', () async {
      await expectLater(
        parse('''
@cobaltBootstrap
class Seed {}
'''),
        rejects(contains("declares no 'run()' method")),
      );
    });
  });
}
