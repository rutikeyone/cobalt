import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gallery/catalog/decorators_graph.dart';
import 'package:gallery/l10n/gallery_l10n.dart';

/// One registration, two wrappers, and the real service reached once a city.
class DecoratorsScreen extends StatelessWidget {
  const DecoratorsScreen({super.key});

  static const _cities = ['Oslo', 'Lima'];

  @override
  Widget build(BuildContext context) {
    final l10n = GalleryL10n.of(context);
    final scope = context.cobaltScope;
    final log = context.cobalt<ForecastLog>();
    final chain = scope.debugDecoratorsOf(const CobaltKey(Weather));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.decoratorsTitle)),
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) => ListView(
          children: [
            ListTile(
              title: Text(l10n.decoratorsChain),
              subtitle: Text(
                ['Station', ...chain].join(' → '),
                key: const Key('decorator-chain'),
              ),
            ),
            ListTile(
              title: const Text('Station'),
              subtitle: Text(
                l10n.decoratorsStationCalls(log.stationCalls),
                key: const Key('station-calls'),
              ),
            ),
            for (final city in _cities)
              ListTile(
                key: Key('ask-$city'),
                title: Text(l10n.decoratorsAsk(city)),
                trailing: const Icon(Icons.cloud_outlined),
                onTap: () => scope.get<Weather>().forecast(city),
              ),
            for (final answer in log.answers.reversed)
              ListTile(dense: true, title: Text(answer)),
          ],
        ),
      ),
    );
  }
}
