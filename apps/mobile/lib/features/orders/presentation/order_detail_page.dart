import 'package:flutter/material.dart';

import '../../pos/domain/order.dart';
import '../../pos/presentation/checkout_controller.dart';
import 'orders_controller.dart';
import 'widgets/order_detail_view.dart';

/// Dedicated order detail screen for compact (mobile) navigation.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.controller,
    required this.reference,
    this.checkoutController,
    this.initialOrder,
  });

  final OrdersController controller;
  final CheckoutController? checkoutController;
  final String reference;
  final Order? initialOrder;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.selectOrder(
          widget.reference,
          initialOrder: widget.initialOrder,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            key: const ValueKey('refresh-order-detail'),
            tooltip: 'Refresh Order Details',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: widget.controller.detailState.busy
                ? null
                : () => widget.controller.refreshOrderDetail(),
          ),
        ],
      ),
      body: OrderDetailView(
        controller: widget.controller,
        checkoutController: widget.checkoutController,
      ),
    );
  }
}
