import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('a class taking call-site values', () {
    test('is registered as a parameterized factory', () {
      final source = generate([
        declare('Repo'),
        declare(
          'NoteEditor',
          constructor: [dep('Repo'), arg('id', 'int'), arg('draft', 'bool')],
        ),
      ]);

      expect(
        source,
        contains('typedef NoteEditorArgs = ({int id, bool draft});'),
      );
      expect(
        source,
        contains('CobaltParamFactory<_i137.NoteEditor, NoteEditorArgs>'),
      );
      expect(
        source,
        contains('registerParamFactory<_i137.NoteEditor, NoteEditorArgs>'),
      );
    });

    test('reads the marked ones from the record and the rest from the graph', () {
      final source = generate([
        declare('Repo'),
        declare('NoteEditor', constructor: [dep('Repo'), arg('id', 'int')]),
      ]);

      // Whitespace-insensitive: the formatter wraps this signature or not
      // depending on how long the type names happen to be, and that is not
      // what the test is about.
      expect(
        source,
        matches(
          RegExp(
            r'create\(\s*_i573\.CobaltResolver resolver,\s*NoteEditorArgs args',
          ),
        ),
      );
      expect(source, contains('resolver.get<_i137.Repo>()'));
      expect(source, contains('id: args.id'));
    });

    /// The check that would otherwise demand a registration for `int`.
    test('a call-site value is not a missing dependency', () {
      expect(
        () => generate([
          declare('NoteEditor', constructor: [arg('id', 'int')]),
        ]),
        returnsNormally,
      );
    });

    test('a call-site value is not an ordering edge either', () {
      final source = generate([
        declare('Logger'),
        declare('NoteEditor', constructor: [arg('id', 'int'), dep('Logger')]),
      ]);
      final order = registrationsOf(source);

      expect(order.first, contains('Logger'));
      expect(
        order.last,
        contains('registerParamFactory'),
        reason: 'the real dependency still orders it; the value does not',
      );
    });

    test('a single value still gets a named record', () {
      final source = generate([
        declare('Detail', constructor: [arg('id', 'int')]),
      ]);

      expect(source, contains('typedef DetailArgs = ({int id});'));
    });

    test('the dollar name stays as a deprecated alias', () {
      final source = generate([
        declare('NoteEditor', constructor: [arg('id', 'int')]),
      ]);

      expect(source, contains('typedef NoteEditorArgs = ({int id});'));
      expect(
        source,
        contains(
          "@Deprecated('Use NoteEditorArgs. Removed in 2.0.')\n"
          r'typedef $NoteEditorArgs = NoteEditorArgs;',
        ),
      );
    });

    test('the plain name is left out when a class already has it', () {
      final source = generate([
        declare('NoteEditor', constructor: [arg('id', 'int')]),
        declare('NoteEditorArgs'),
      ]);

      expect(source, contains(r'typedef $NoteEditorArgs ='));
      expect(source, isNot(contains('typedef NoteEditorArgs =')));
    });

    test('a named registration keeps its name in both places', () {
      final source = generate([
        declare('Detail', name: 'wide', constructor: [arg('id', 'int')]),
      ]);

      expect(source, contains('typedef DetailWideArgs'));
      expect(source, contains("name: 'wide'"));
    });
  });

  group('a constructor with named parameters', () {
    test('is called the way it was declared', () {
      final source = generate([
        declare('Logger'),
        declare(
          'Api',
          constructor: [dep('Logger', isNamed: true, field: 'logger')],
        ),
      ]);

      expect(source, contains('logger: resolver.get<_i137.Logger>()'));
      expect(
        'resolver.get<_i137.Logger>()'.allMatches(source).length,
        1,
        reason:
            'passed once, as the named parameter it was declared as — '
            'emitting it positionally as well compiles to nothing valid',
      );
    });

    test('mixes positional and named in the right places', () {
      final source = generate([
        declare('Logger'),
        declare('Clock'),
        declare(
          'Api',
          constructor: [
            dep('Clock'),
            dep('Logger', isNamed: true, field: 'logger'),
          ],
        ),
      ]);

      final call = source.substring(source.indexOf('_i137.Api('));
      expect(
        call.indexOf('resolver.get<_i137.Clock>()'),
        lessThan(call.indexOf('logger:')),
        reason:
            'positional first, named after, whatever the formatter does '
            'with the line breaks',
      );
      expect(
        'resolver.get<_i137.Logger>()'.allMatches(source).length,
        1,
        reason: 'the named one appears once, not also among the positionals',
      );
    });
  });
}
