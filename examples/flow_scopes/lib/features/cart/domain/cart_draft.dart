import 'package:cobalt_go_router/cobalt_go_router.dart';
import 'package:flow_scopes/core/event_log.dart';
import 'package:flow_scopes/core/flow_event.dart';

/// What the cart flow is holding on to while the user moves between its
/// three screens.
///
/// The screens sit at `/cart`, `/checkout` and `/payment` — three top-level
/// routes with nothing in their paths in common. They still share this one
/// draft, because they share one shell.
class CartDraft implements Disposable {
  CartDraft(this._log) {
    _log.record(const FlowEvent(FlowEventKind.cartCreated, 'cart'));
  }

  final EventLog _log;

  @override
  void dispose() =>
      _log.record(const FlowEvent(FlowEventKind.cartDisposed, 'cart'));
}

final class CartDraftFactory implements CobaltFactory<CartDraft> {
  const CartDraftFactory();

  @override
  CartDraft create(CobaltResolver resolver) =>
      CartDraft(resolver.get<EventLog>());
}
