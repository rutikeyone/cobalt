import 'package:cobalt/cobalt.dart';

@CobaltChildScope()
class OrderFlow {
  const OrderFlow(@Named('orderId') this.orderId);

  final String orderId;
}
