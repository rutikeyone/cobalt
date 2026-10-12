import 'package:cobalt/cobalt.dart';

@CobaltChildScope()
class OrderFlow {
  const OrderFlow(this.orderId);

  final String orderId;
}
