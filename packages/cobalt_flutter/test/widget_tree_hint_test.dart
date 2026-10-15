import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Greeting {
  const Greeting();
}

class Api {
  const Api(this.greeting);

  final Greeting greeting;
}

class SessionScope implements CobaltScopeBuilder {
  const SessionScope();

  @override
  void build(CobaltScope scope) =>
      scope.registerSingleton<Greeting>(const Greeting());
}

void main() {
  late CobaltScope app;
  late BuildContext captured;

  Future<void> pumpUnder(WidgetTester tester, CobaltScope scope) =>
      tester.pumpWidget(
        CobaltScopeProvider(
          scope: scope,
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      );

  setUp(() => app = CobaltScope.root(name: 'app'));

  tearDown(() => app.dispose());

  testWidgets('a scope from open is named with the way to publish it', (
    tester,
  ) async {
    await tester.runAsync(() => app.open('session', const SessionScope()));
    await pumpUnder(tester, app);

    expect(
      () => captured.cobalt<Greeting>(),
      throwsA(
        isA<CobaltNotRegisteredError>()
            .having((error) => error.registeredElsewhere, 'elsewhere', [
              'session',
            ])
            .having(
              (error) => error.hint,
              'hint',
              allOf(
                contains('above it in the widget tree'),
                contains('"session"'),
                contains('CobaltScopeProvider(scope: ...'),
                contains('CobaltScopeWidget'),
              ),
            ),
      ),
    );
  });

  testWidgets('the async reads carry it too', (tester) async {
    await tester.runAsync(() => app.open('session', const SessionScope()));
    await pumpUnder(tester, app);

    await expectLater(
      captured.cobaltAsync<Greeting>(),
      throwsA(
        isA<CobaltNotRegisteredError>().having(
          (error) => error.hint,
          'hint',
          contains('widget tree'),
        ),
      ),
    );
  });

  testWidgets('nothing elsewhere means no hint', (tester) async {
    await pumpUnder(tester, app);

    expect(
      () => captured.cobalt<Greeting>(),
      throwsA(
        isA<CobaltNotRegisteredError>().having(
          (error) => error.hint,
          'hint',
          isNull,
        ),
      ),
    );
  });

  testWidgets('a factory that asked gets no widget hint', (tester) async {
    app.registerLazySingleton<Api>(_ApiFactory());
    await tester.runAsync(() => app.open('session', const SessionScope()));
    await pumpUnder(tester, app);

    expect(
      () => captured.cobalt<Api>(),
      throwsA(
        isA<CobaltNotRegisteredError>()
            .having((error) => error.resolving, 'resolving', isNotEmpty)
            .having((error) => error.hint, 'hint', isNull),
      ),
    );
  });
}

class _ApiFactory implements CobaltFactory<Api> {
  @override
  Api create(CobaltResolver resolver) => Api(resolver.get<Greeting>());
}
