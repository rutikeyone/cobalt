import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:cobalt_test/cobalt_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Formatter {
  const Formatter(this.label);

  final String label;
}

class Ticket {
  const Ticket(this.id);

  final String id;
}

final class TicketFactory implements CobaltParamFactory<Ticket, String> {
  const TicketFactory();

  @override
  Ticket create(CobaltResolver resolver, String param) => Ticket(param);
}

void main() {
  late CobaltScope scope;

  setUp(() {
    scope = cobaltTestRoot(name: 'app')
      ..registerSingleton<Formatter>(const Formatter('plain'), name: 'plain')
      ..registerSingleton<Formatter>(const Formatter('shout'), name: 'shout')
      ..registerParamFactory<Ticket, String>(const TicketFactory());
  });

  Future<T> read<T>(WidgetTester tester, T Function(BuildContext) of) async {
    late T value;
    await tester.pumpWidget(
      CobaltScopeProvider(
        scope: scope,
        child: Builder(
          builder: (context) {
            value = of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return value;
  }

  /// Both of these are convenience the framework advertises and coverage found
  /// no test calling — the same shape of gap as the sinks in phase 26.
  group('the context extension', () {
    testWidgets('cobaltAll returns every registration of a type', (
      tester,
    ) async {
      final all = await read(
        tester,
        (context) => context.cobaltAll<Formatter>(),
      );

      expect(
        all.map((formatter) => formatter.label),
        ['plain', 'shout'],
        reason: 'in registration order, like getAll itself',
      );
    });

    testWidgets('cobaltWithParam passes the argument through', (tester) async {
      final ticket = await read(
        tester,
        (context) => context.cobaltWithParam<Ticket, String>('A7'),
      );

      expect(ticket.id, 'A7');
    });

    testWidgets('cobaltScope is the scope the provider published', (
      tester,
    ) async {
      final read0 = await read(tester, (context) => context.cobaltScope);

      expect(identical(read0, scope), isTrue);
    });

    testWidgets('a miss through the extension names the key', (tester) async {
      await tester.pumpWidget(
        CobaltScopeProvider(
          scope: scope,
          child: Builder(
            builder: (context) {
              expect(
                () => context.cobalt<Ticket>(),
                throwsA(isA<CobaltParamRequiredError>()),
                reason:
                    'a parameterized registration read without its argument',
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
