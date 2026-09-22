import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:codegen_basics/cobalt.g.dart';
import 'package:codegen_basics/counter_bloc.dart';
import 'package:codegen_basics/greeting.dart';
import 'package:codegen_basics/l10n/codegen_basics_l10n.dart';
import 'package:codegen_basics/leaderboard.dart';
import 'package:flutter/material.dart';

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(CodegenBasicsL10n.of(context).appTitle)),
    // A scope that lives exactly as long as this screen. The bloc below is a
    // transient, so it would be rebuilt on every resolve — putting it in a
    // scope of its own is what gives it a lifetime and a disposal point.
    body: const CobaltScopeWidget(
      name: 'counter-screen',
      builder: _ScreenScope(),
      child: _Counter(),
    ),
  );
}

/// Registers nothing new — it exists to give the screen its own node in the
/// scope tree, which is where screen-scoped state would go as the app grows.
final class _ScreenScope implements CobaltScopeBuilder {
  const _ScreenScope();

  @override
  void build(CobaltScope scope) {}
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  late final CounterBloc _bloc = context.cobalt<CounterBloc>();

  @override
  Widget build(BuildContext context) {
    final l10n = CodegenBasicsL10n.of(context);
    // A parameterized registration: the config comes from the graph, the name
    // and the flag from here.
    final greeting = context.cobaltWithParam<Greeting, $GreetingArgs>((
      name: 'Cobalt',
      loud: false,
    ));

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_bloc.value}',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          Text(l10n.environment(_bloc.environment)),
          Text(
            greeting.render(l10n.greeting(greeting.name, greeting.environment)),
          ),
          CobaltAsyncBuilder<Leaderboard>(
            loading: Text(l10n.leaderboardLoading),
            builder: (context, board) =>
                Text(l10n.leaderboardReady(board.entries)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(_bloc.increment),
            child: Text(l10n.increment),
          ),
        ],
      ),
    );
  }
}
