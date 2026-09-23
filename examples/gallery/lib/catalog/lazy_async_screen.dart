import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gallery/catalog/lazy_async_graph.dart';
import 'package:gallery/l10n/gallery_l10n.dart';

/// Startup has finished, and the engine is still not built.
class LazyAsyncScreen extends StatelessWidget {
  const LazyAsyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = GalleryL10n.of(context);
    final builds = context.cobalt<EngineBuilds>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lazyAsyncTitle)),
      body: ListenableBuilder(
        listenable: builds,
        builder: (context, _) => ListView(
          children: [
            ListTile(
              title: Text(l10n.lazyAsyncStarted),
              subtitle: Text(
                l10n.lazyAsyncBuilds(builds.count),
                key: const Key('engine-builds'),
              ),
            ),
            ListTile(
              key: const Key('open-search'),
              title: Text(l10n.lazyAsyncOpen),
              subtitle: Text(l10n.lazyAsyncOpenDetail),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSearch(context),
            ),
          ],
        ),
      ),
    );
  }

  /// The pushed route is built by the navigator, which sits above the scope
  /// this screen resolves from — so the scope is read here and handed over.
  void _openSearch(BuildContext context) {
    final scope = context.cobaltScope;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CobaltScopeProvider(scope: scope, child: const _SearchScreen()),
      ),
    );
  }
}

class _SearchScreen extends StatelessWidget {
  const _SearchScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = GalleryL10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lazyAsyncSearchTitle)),
      body: CobaltAsyncBuilder<SearchEngine>(
        loading: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.lazyAsyncBuilding),
            ],
          ),
        ),
        errorBuilder: (context, error, retry) => Center(
          child: FilledButton(onPressed: retry, child: Text(l10n.hostRetry)),
        ),
        builder: (context, engine) => ListView(
          children: [
            ListTile(
              key: const Key('engine-ready'),
              title: const Text('getAsync<SearchEngine>()'),
              subtitle: Text(
                l10n.lazyAsyncReady('${identityHashCode(engine)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
