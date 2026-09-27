import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gallery/design/gallery_theme.dart';
import 'package:gallery/l10n/gallery_l10n.dart';

/// Mounts one example with its own root scope.
///
/// The graph is built when this route is pushed and disposed when it is
/// popped, so opening an example twice gives you two unrelated graphs — which
/// is the whole point of the gallery. `CobaltAppScope` is used directly rather
/// than through `.builder`: there is already a `MaterialApp` above, so loading
/// and error render under the gallery's theme without one of their own.
///
/// There is no per-example palette. Every example is painted by the one theme
/// above, so moving between them changes what the graph does and nothing else.
class ExampleHost extends StatelessWidget {
  const ExampleHost({
    required this.root,
    required this.child,
    this.bootstrap,
    this.rootName = 'root',
    this.observers = const [],
    this.overrides,
    super.key,
  });

  final CobaltScopeBuilder root;
  final Widget child;
  final List<CobaltBootstrapStep> Function()? bootstrap;
  final String rootName;
  final List<CobaltObserver> observers;
  final List<CobaltOverride<Object>> Function()? overrides;

  @override
  Widget build(BuildContext context) => CobaltAppScope(
    root: root,
    bootstrap: bootstrap,
    rootName: rootName,
    observers: observers,
    overrides: overrides,
    loading: const _Starting(),
    errorBuilder: (context, error, retry) =>
        _StartupFailed(error: error, retry: retry),
    child: child,
  );
}

class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _StartupFailed extends StatelessWidget {
  const _StartupFailed({required this.error, required this.retry});

  final Object error;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final l10n = GalleryL10n.of(context);
    final text = GalleryText.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.hostFailed, style: text.cardTitle),
              const SizedBox(height: 12),
              Text('$error', style: text.cardBody),
              const SizedBox(height: 20),
              FilledButton(onPressed: retry, child: Text(l10n.hostRetry)),
            ],
          ),
        ),
      ),
    );
  }
}
