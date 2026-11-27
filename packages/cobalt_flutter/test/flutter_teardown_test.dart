import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape almost every Flutter object has: a `dispose` the scope cannot see.
class Counter extends ChangeNotifier {
  var isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

/// The same class, saying so.
///
/// Nothing else changes: `ChangeNotifier.dispose` already matches
/// [Disposable.dispose], so the declaration is the whole fix.
class DeclaredCounter extends ChangeNotifier implements Disposable {
  var isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

/// The shape a `Bloc` or `Cubit` has: closing is asynchronous and is not
/// called `dispose`.
class Session {
  var isClosed = false;

  Future<void> close() async => isClosed = true;
}

/// The same class, bridged in one line.
class DeclaredSession implements AsyncDisposable {
  var isClosed = false;

  Future<void> close() async => isClosed = true;

  @override
  Future<void> dispose() => close();
}

class Closing implements AsyncDisposable {
  Closing(this.label, this.log);

  final String label;
  final List<String> log;

  @override
  Future<void> dispose() async {
    log.add('$label start');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    log.add('$label end');
  }
}

class _Graph implements CobaltScopeBuilder {
  const _Graph(this.label, this.log);

  final String label;
  final List<String> log;

  @override
  void build(CobaltScope scope) => scope.registerSingleton(Closing(label, log));
}

void main() {
  test('a ChangeNotifier the scope cannot recognise is not released', () async {
    final scope = cobaltTestRoot();
    final counter = Counter();
    scope.registerSingleton<Counter>(counter);

    await scope.dispose();

    expect(
      counter.isDisposed,
      isFalse,
      reason:
          'a scope releases what implements Disposable or AsyncDisposable, or '
          'what a registration named a dispose function for. Dart has no '
          'structural typing, so a matching method signature is not enough — '
          'and this is the single most common way to leak with Cobalt',
    );
  });

  test('declaring the interface is the whole fix', () async {
    final scope = cobaltTestRoot();
    final counter = DeclaredCounter();
    scope.registerSingleton<DeclaredCounter>(counter);

    await scope.dispose();

    expect(counter.isDisposed, isTrue);
  });

  test('a Bloc-shaped close is reached by AsyncDisposable', () async {
    final scope = cobaltTestRoot();
    final session = DeclaredSession();
    scope.registerSingleton<DeclaredSession>(session);

    await scope.dispose();

    expect(session.isClosed, isTrue);
  });

  test('or by naming the function at the registration', () async {
    final scope = cobaltTestRoot();
    final session = Session();
    scope.registerSingleton<Session>(session, dispose: (it) => it.close());

    await scope.dispose();

    expect(
      session.isClosed,
      isTrue,
      reason: 'the route for a type you did not write and cannot change',
    );
  });

  testWidgets('a screen scope is closed before the app scope above it', (
    tester,
  ) async {
    final log = <String>[];
    await tester.pumpWidget(
      CobaltAppScope(
        root: _Graph('root', log),
        child: CobaltScopeWidget(
          builder: _Graph('screen', log),
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(log, ['screen start', 'screen end', 'root start', 'root end']);
  });
}
