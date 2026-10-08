import 'package:cobalt_analyzer/cobalt_analyzer.dart';
import 'package:test/test.dart';

CobaltTypeRef ref(
  String name, {
  List<CobaltTypeRef> of = const [],
  bool isNullable = false,
}) => CobaltTypeRef(
  name: name,
  import: 'package:app/app.dart',
  typeArguments: of,
  isNullable: isNullable,
);

void main() {
  group('signature', () {
    test('separates instantiations of the same generic', () {
      expect(
        ref('Repository', of: [ref('User')]).signature,
        isNot(ref('Repository', of: [ref('Order')]).signature),
      );
    });

    test('ignores nullability, which is never emitted into a resolve', () {
      expect(ref('Foo', isNullable: true).signature, ref('Foo').signature);
    });

    test('keeps the nullability of a type argument', () {
      expect(
        ref('Cache', of: [ref('Note', isNullable: true)]).signature,
        isNot(ref('Cache', of: [ref('Note')]).signature),
      );
    });

    test('is recursive', () {
      expect(
        ref(
          'Box',
          of: [
            ref('List', of: [ref('User')]),
          ],
        ).signature,
        isNot(
          ref(
            'Box',
            of: [
              ref('List', of: [ref('Order')]),
            ],
          ).signature,
        ),
      );
    });

    test('separates same-named types from different libraries', () {
      const here = CobaltTypeRef(name: 'Clock', import: 'package:a/a.dart');
      const there = CobaltTypeRef(name: 'Clock', import: 'package:b/b.dart');
      expect(here.signature, isNot(there.signature));
    });
  });

  group('equality', () {
    test('follows the signature', () {
      expect(
        ref('Repository', of: [ref('User')]),
        ref('Repository', of: [ref('User')]),
      );
      expect(
        ref('Repository', of: [ref('User')]),
        isNot(ref('Repository', of: [ref('Order')])),
      );
      expect(
        ref('Repository', of: [ref('User')]).hashCode,
        isNot(ref('Repository', of: [ref('Order')]).hashCode),
      );
    });
  });

  group('toString', () {
    test('shows type arguments and nullability', () {
      expect(
        ref('Repository', of: [ref('User')]).toString(),
        'Repository<User>',
      );
      expect(ref('Foo', isNullable: true).toString(), 'Foo?');
    });
  });
}
