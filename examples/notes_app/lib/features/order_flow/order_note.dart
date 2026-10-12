import 'package:cobalt/cobalt.dart';
import 'package:notes_app/core/event_log.dart';
import 'package:notes_app/features/order_flow/order_flow.dart';

@CobaltInject(scope: OrderFlow)
class OrderNote implements Disposable {
  OrderNote(this.orderId, this._log) {
    _log.record('order $orderId opened');
  }

  final String orderId;
  final EventLog _log;

  @override
  void dispose() => _log.record('order $orderId closed');
}
