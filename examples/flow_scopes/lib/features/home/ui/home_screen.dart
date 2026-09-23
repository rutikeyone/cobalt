import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:flow_scopes/app/app_routes.dart';
import 'package:flow_scopes/core/event_log.dart';
import 'package:flow_scopes/core/flow_event.dart';
import 'package:flow_scopes/l10n/flow_scopes_l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = FlowScopesL10n.of(context);
    final log = context.cobalt<EventLog>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            key: const Key('open-scope-tree'),
            tooltip: l10n.whatIsAlive,
            icon: const Icon(Icons.account_tree),
            onPressed: () => context.go(AppRoutes.scopeTree),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: log,
        builder: (context, _) => ListView(
          children: [
            ListTile(
              title: Text(l10n.openAFlow),
              subtitle: Text(l10n.openAFlowDetail),
            ),
            for (final orderId in const ['1', '2'])
              ListTile(
                key: Key('open-order-$orderId'),
                title: Text(l10n.order(orderId)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(AppRoutes.summary(orderId)),
              ),
            ListTile(
              key: const Key('open-cart'),
              title: Text(l10n.openCart),
              subtitle: Text(l10n.openCartDetail),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.cart),
            ),
            ListTile(
              key: const Key('open-workspace'),
              title: Text(l10n.workspaceTabs),
              subtitle: Text(l10n.workspaceTabsDetail),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.workspaceFeed),
            ),
            const Divider(),
            ListTile(title: Text(l10n.eventLog)),
            if (log.entries.isEmpty)
              ListTile(
                dense: true,
                title: Text(l10n.logEmpty, key: const Key('log-empty')),
              ),
            for (final entry in log.entries)
              ListTile(
                dense: true,
                title: Text(_say(l10n, entry), key: Key('log-$entry')),
              ),
          ],
        ),
      ),
    );
  }

  /// Names one recorded event.
  ///
  /// The switch lives here rather than on [FlowEvent] for the reason the type
  /// exists: the domain knows what happened, the screen knows the language.
  String _say(FlowScopesL10n l10n, FlowEvent event) => switch (event.kind) {
    FlowEventKind.scopeBuilt => l10n.scopeBuilt(event.subject),
    FlowEventKind.scopeDisposed => l10n.scopeDisposed(event.subject),
    FlowEventKind.draftCreated => l10n.draftCreated(event.subject),
    FlowEventKind.draftDisposed => l10n.draftDisposed(event.subject),
    FlowEventKind.cartCreated => l10n.cartCreated,
    FlowEventKind.cartDisposed => l10n.cartDisposed,
  };
}
