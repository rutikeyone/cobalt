// ignore_for_file: non_constant_identifier_names

import 'package:cobalt_lint/src/fixes/use_bloc_provider_value.dart';
import 'package:cobalt_lint/src/rules/bloc_provider_closes_a_scoped_bloc.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_support.dart';
import 'support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(BlocProviderClosesAScopedBlocTest);
  });
}

const _stubs = '''
class BlocProvider {
  BlocProvider({required Object Function(Object) create, Object? child, bool? lazy});
  BlocProvider.value({required Object value, Object? child});
}

class Context {}

extension on Context {
  T cobalt<T>() => throw 0;
}

class CounterCubit {}
''';

String _widget(String provider) =>
    '''
$_stubs
Object build(Context context) => $provider;
''';

@reflectiveTest
class BlocProviderClosesAScopedBlocTest extends AnalysisRuleTest {
  @override
  void setUp() {
    stubCobaltAnnotations(this);
    rule = BlocProviderClosesAScopedBloc();
    super.setUp();
  }

  void test_createReadingTheScope_isReported() async {
    final source = _widget(
      'BlocProvider(create: (_) => context.cobalt<CounterCubit>())',
    );
    final create = 'create: (_) => context.cobalt<CounterCubit>()';

    await assertDiagnostics(source, [
      lint(source.indexOf(create), create.length),
    ]);
  }

  void test_createBuildingItsOwn_isClean() async {
    await assertNoDiagnostics(
      _widget('BlocProvider(create: (_) => CounterCubit())'),
    );
  }

  void test_valueReadingTheScope_isClean() async {
    await assertNoDiagnostics(
      _widget('BlocProvider.value(value: context.cobalt<CounterCubit>())'),
    );
  }

  void test_fix_rewritesToValue() async {
    expect(
      await fixed(
        _widget(
          'BlocProvider(create: (_) => context.cobalt<CounterCubit>(), '
          'child: 1)',
        ),
        UseBlocProviderValue.new,
      ),
      _widget(
        'BlocProvider.value(value: context.cobalt<CounterCubit>(), child: 1)',
      ),
    );
  }

  void test_fix_keepsItsHandsOffLazy() async {
    expect(
      await fixed(
        _widget(
          'BlocProvider(create: (_) => context.cobalt<CounterCubit>(), '
          'lazy: false)',
        ),
        UseBlocProviderValue.new,
      ),
      isNull,
    );
  }

  void test_fix_keepsItsHandsOffABlockBody() async {
    expect(
      await fixed(
        _widget(
          'BlocProvider(create: (_) { return context.cobalt<CounterCubit>(); })',
        ),
        UseBlocProviderValue.new,
      ),
      isNull,
    );
  }
}
