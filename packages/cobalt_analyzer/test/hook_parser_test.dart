import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

import 'support.dart';

Matcher rejects(Object matcher) => throwsA(
  isA<CobaltParseError>().having((e) => e.message, 'message', matcher),
);

void main() {
  const parser = CobaltHookParser();

  Future<CobaltHookClass> parse(String source) async =>
      parser.parseClass(await classNamed('Join', source));

  const runtime = '''
import 'package:cobalt/cobalt.dart';

abstract interface class Loggable {}
''';

  group('what it reads', () {
    test('the class, and what it runs on from CobaltHook<T>', () async {
      final hook = await parse('''
$runtime
@cobaltHookAll
final class Join extends CobaltHook<Loggable> {
  const Join();
  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) {}
}
''');

      expect(hook.type.name, 'Join');
      expect(hook.target.name, 'Loggable');
      expect(hook.order, 0);
      expect(hook.environments, isEmpty);
    });

    test('its order and environments', () async {
      final hook = await parse('''
$runtime
@CobaltHookAll(order: -2)
@CobaltEnvironment.dev
final class Join extends CobaltHook<Loggable> {
  Join({this.verbose = false});
  final bool verbose;
  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) {}
}
''');

      expect(hook.order, -2);
      expect(hook.environments, {'dev'});
    });

    test('survives the trip through the build JSON', () async {
      final hook = await parse('''
$runtime
@cobaltHookAll
final class Join extends CobaltHook<Loggable> {
  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) {}
}
''');
      final back = CobaltLibraryDeclarations.fromJson(
        CobaltLibraryDeclarations(hooks: [hook]).toJson(),
      ).hooks.single;

      expect(back.type.name, 'Join');
      expect(back.target.signature, hook.target.signature);
    });
  });

  group('what it refuses', () {
    test('a class that is not a CobaltHook', () async {
      await expectLater(
        parse('''
$runtime
@cobaltHookAll
class Join {}
'''),
        rejects(contains('does not extend CobaltHook<T>')),
      );
    });

    test('a constructor that wants something injected', () async {
      await expectLater(
        parse('''
$runtime
class Registry {}
@cobaltHookAll
final class Join extends CobaltHook<Loggable> {
  Join(this.registry);
  final Registry registry;
  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) {}
}
'''),
        rejects(contains('without required parameters')),
      );
    });

    test('a class that is also a registration', () async {
      await expectLater(
        parse('''
$runtime
@cobaltHookAll
@cobaltInject
final class Join extends CobaltHook<Loggable> {
  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) {}
}
'''),
        rejects(contains('both a hook and a registration')),
      );
    });

    test('an abstract class', () async {
      await expectLater(
        parse('''
$runtime
@cobaltHookAll
abstract base class Join extends CobaltHook<Loggable> {}
'''),
        rejects(contains('abstract')),
      );
    });

    test('a class with type parameters', () async {
      await expectLater(
        parse('''
$runtime
@cobaltHookAll
final class Join<T> extends CobaltHook<Loggable> {
  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) {}
}
'''),
        rejects(contains('declares type parameters')),
      );
    });

    test('a class with no public generative constructor', () async {
      await expectLater(
        parse('''
$runtime
@cobaltHookAll
final class Join extends CobaltHook<Loggable> {
  Join._();
  factory Join.create() => Join._();
  @override
  void onBuilt(Loggable instance, CobaltResolver resolver) {}
}
'''),
        rejects(contains('no public generative constructor')),
      );
    });
  });
}
