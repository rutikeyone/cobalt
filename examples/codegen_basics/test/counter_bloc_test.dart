import 'package:cobalt/cobalt.dart';
import 'package:codegen_basics/cobalt.g.dart';
import 'package:codegen_basics/counter_bloc.dart';
import 'package:codegen_basics/services.dart';
import 'package:flutter_test/flutter_test.dart';

class LoudTelemetry extends Telemetry {
  LoudTelemetry();
}

class LoudTelemetryFactory implements CobaltFactory<Telemetry> {
  const LoudTelemetryFactory();

  @override
  Telemetry create(CobaltResolver resolver) => LoudTelemetry();
}

class CounterBlocOverride implements CobaltFactory<CounterBloc> {
  const CounterBlocOverride();

  @override
  CounterBloc create(CobaltResolver resolver) => CounterBloc();
}

void main() {
  late CobaltScope app;

  setUp(() async {
    app = await CobaltApplication.start(
      root: const CobaltRoot(),
      rootName: 'app',
    );
  });

  tearDown(() async => app.dispose());

  test(
    'the generated container registers everything the annotations declare',
    () {
      expect(app.isRegistered<Config>(), isTrue);
      expect(app.isRegistered<Repository>(), isTrue);
      expect(app.isRegistered<Telemetry>(), isTrue);
      expect(app.isRegistered<CounterBloc>(), isTrue);
    },
  );

  test('lifetimes follow the annotation, not a convention', () {
    expect(app.get<Repository>(), same(app.get<Repository>()));
    expect(app.get<CounterBloc>(), isNot(same(app.get<CounterBloc>())));
  });

  test('the generated mixin injects private late final fields', () {
    final bloc = app.get<CounterBloc>();

    expect(bloc, isA<CobaltInjectable>());
    expect(bloc.environment, 'test');
  });

  test('an injected bloc has no constructor parameters at all', () {
    final bloc = CounterBloc();

    expect(() => bloc.value, throwsA(isA<Error>()));

    bloc.onInject(app);
    expect(bloc.value, 0);
  });

  test('injected singletons are shared across blocs', () {
    app.get<CounterBloc>().increment();

    expect(app.get<CounterBloc>().value, 1);
    expect(app.get<Telemetry>().events, ['increment -> 1']);
  });

  test('a child scope overrides one generated registration', () {
    final session = app.push('session')
      ..registerFactory<CounterBloc>(const CounterBlocOverride())
      ..registerLazySingleton<Telemetry>(const LoudTelemetryFactory());

    session.get<CounterBloc>().increment();

    expect(session.get<Telemetry>(), isA<LoudTelemetry>());
    expect(session.get<Telemetry>().events, ['increment -> 1']);
    expect(app.get<Telemetry>().events, isEmpty);
    expect(app.get<Repository>(), same(session.get<Repository>()));
  });

  test('disposing the app closes injected disposables', () async {
    final telemetry = app.get<Telemetry>();
    await app.dispose();

    expect(telemetry.isClosed, isTrue);
  });
}
