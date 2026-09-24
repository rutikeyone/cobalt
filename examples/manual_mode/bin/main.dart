import 'package:cobalt/cobalt.dart';
import 'package:manual_mode/counter.dart';

Future<void> main() async {
  // Pure Dart: no Flutter binding, no widget tree. CobaltPrintLogSink writes to
  // stdout, which is the right default outside an app — CobaltDeveloperLogSink
  // would need a debugger attached to be worth anything.
  final app = await startApp(
    observers: [CobaltLogObserver(const CobaltPrintLogSink())],
  );

  final session = openSession(app, 'alice');
  final counter = session.getWithParam<Counter, String>('alice');

  counter
    ..increment()
    ..increment();

  print('value: ${counter.value}');
  print(
    'audit: ${app.get<EventLog>().entries.where((e) => e.startsWith('audited')).join(', ')}',
  );
  print('scopes: ${app.name} -> ${app.children.map((s) => s.name).join()}');

  await session.dispose();
  print(
    'after session dispose, storage open: '
    '${!app.get<CounterStorage>().isClosed}',
  );

  await app.dispose();
  print('app disposed: ${app.state == CobaltScopeState.disposed}');
}
