import 'dart:async';

import 'package:cobalt_flutter/cobalt_flutter.dart';
import 'package:flutter/material.dart';
import 'package:gallery/catalog/async_transient_graph.dart';
import 'package:gallery/l10n/gallery_l10n.dart';

/// Every getAsync builds a report of its own, and the scope keeps none.
class AsyncTransientScreen extends StatelessWidget {
  const AsyncTransientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = GalleryL10n.of(context);
    final desk = context.cobalt<ReportDesk>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.asyncTransientTitle)),
      body: ListenableBuilder(
        listenable: desk,
        builder: (context, _) => ListView(
          children: [
            ListTile(
              title: Text(l10n.asyncTransientStarted),
              subtitle: Text(
                l10n.asyncTransientBuilds(desk.built),
                key: const Key('report-builds'),
              ),
            ),
            ListTile(
              key: const Key('build-one'),
              title: Text(l10n.asyncTransientOne),
              subtitle: Text(l10n.asyncTransientOneDetail),
              trailing: const Icon(Icons.description_outlined),
              onTap: () => _ask(context, 1),
            ),
            ListTile(
              key: const Key('build-two'),
              title: Text(l10n.asyncTransientTwo),
              subtitle: Text(l10n.asyncTransientTwoDetail),
              trailing: const Icon(Icons.copy_all_outlined),
              onTap: () => _ask(context, 2),
            ),
            for (final report in desk.received.reversed)
              ListTile(
                dense: true,
                title: Text(
                  l10n.asyncTransientReceived(
                    report.number,
                    '${identityHashCode(report)}',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Asks [count] times at once. Each call is its own build — nothing is
  /// shared, and the desk receives what the caller now owns.
  void _ask(BuildContext context, int count) {
    final scope = context.cobaltScope;
    final desk = context.cobalt<ReportDesk>();
    unawaited(
      Future.wait([
        for (var i = 0; i < count; i++) scope.getAsync<Report>(),
      ]).then((reports) => reports.forEach(desk.receive)),
    );
  }
}
