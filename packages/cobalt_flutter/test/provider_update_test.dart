import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Label {
  const Label(this.text);

  final String text;
}

CobaltScope scopeSaying(String text) =>
    cobaltTestRoot(name: 'app')..registerSingleton<Label>(Label(text));

/// Swaps the scope in place, keeping one child instance for the whole test.
///
/// Rebuilding the tree from `pumpWidget` would prove nothing: the reader would
/// be rebuilt because its ancestors were, whatever the provider decided. Here
/// the child widget is the same object every time, so the only thing that can
/// rebuild it is the provider notifying its dependents.
class _Host extends StatefulWidget {
  const _Host({required this.child, required this.first, super.key});

  final Widget child;
  final CobaltScope first;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late CobaltScope _scope = widget.first;

  void swap(CobaltScope next) => setState(() => _scope = next);

  @override
  Widget build(BuildContext context) =>
      CobaltScopeProvider(scope: _scope, child: widget.child);
}

class _Reader extends StatelessWidget {
  const _Reader({required this.builds});

  final List<String> builds;

  @override
  Widget build(BuildContext context) {
    final text = context.cobalt<Label>().text;
    builds.add(text);
    return Text(text, textDirection: TextDirection.ltr);
  }
}

class Screen implements CobaltScopeBuilder {
  const Screen();

  @override
  void build(CobaltScope scope) => scope.registerLazySingleton<String>(
    FnFactory((resolver) => 'screen ${resolver.get<Label>().text}'),
  );
}

class _ScreenText extends StatelessWidget {
  const _ScreenText();

  @override
  Widget build(BuildContext context) =>
      Text(context.cobalt<String>(), textDirection: TextDirection.ltr);
}

class Visit {}

final class VisitScope extends CobaltChildScopeBuilder {
  VisitScope(this.id, this.builds);

  final int id;
  final List<int> builds;

  @override
  Type get marker => Visit;

  @override
  List<Object?> get markerValues => [id];

  @override
  void build(CobaltScope scope) => builds.add(id);
}

void main() {
  /// A mutation making `updateShouldNotify` always return false passed every
  /// test in this package. Swapping the scope is how a restarted graph reaches
  /// the widgets below it, so it is pinned here.
  group('a provider handed a different scope', () {
    testWidgets('rebuilds what read the old one', (tester) async {
      final builds = <String>[];
      final key = GlobalKey<_HostState>();

      await tester.pumpWidget(
        _Host(
          key: key,
          first: scopeSaying('first'),
          child: _Reader(builds: builds),
        ),
      );
      expect(builds, ['first']);

      key.currentState!.swap(scopeSaying('second'));
      await tester.pump();

      expect(builds, ['first', 'second']);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('leaves it alone when handed the same scope again', (
      tester,
    ) async {
      final builds = <String>[];
      final key = GlobalKey<_HostState>();
      final scope = scopeSaying('only');

      await tester.pumpWidget(
        _Host(
          key: key,
          first: scope,
          child: _Reader(builds: builds),
        ),
      );
      expect(builds, ['only']);

      key.currentState!.swap(scope);
      await tester.pump();

      expect(
        builds,
        ['only'],
        reason:
            'the same scope object is not a change, and notifying anyway '
            'would rebuild every reader on any parent rebuild',
      );
    });
  });

  group('a scope widget below a provider handed a different scope', () {
    testWidgets('closes its scope and opens one under the new scope', (
      tester,
    ) async {
      final key = GlobalKey<_HostState>();
      final first = scopeSaying('first');
      final second = scopeSaying('second');

      await tester.pumpWidget(
        _Host(
          key: key,
          first: first,
          child: const CobaltScopeWidget(
            builder: Screen(),
            child: _ScreenText(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('screen first'), findsOneWidget);

      key.currentState!.swap(second);
      await tester.pump();
      await tester.pump();

      expect(find.text('screen second'), findsOneWidget);
      expect(first.children, isEmpty);
      expect(second.children, hasLength(1));
    });

    testWidgets('opens once when the builder changes in the same frame', (
      tester,
    ) async {
      final builds = <int>[];
      final first = scopeSaying('first');
      final second = scopeSaying('second');
      Widget tree(CobaltScope scope, int id) => CobaltScopeProvider(
        scope: scope,
        child: CobaltScopeWidget(
          builder: VisitScope(id, builds),
          child: const SizedBox.shrink(),
        ),
      );

      await tester.pumpWidget(tree(first, 1));
      await tester.pumpWidget(tree(second, 2));

      expect(builds, [1, 2]);
      expect(first.children, isEmpty);
      expect(second.children, hasLength(1));
    });
  });
}
