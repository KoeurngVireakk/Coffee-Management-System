import 'package:flutter/material.dart';

import '../domain/inventory_item.dart';
import 'inventory_controller.dart';
import 'widgets/inventory_detail_view.dart';

/// Standalone mobile screen for inspecting inventory item details on compact viewports.
class InventoryDetailPage extends StatelessWidget {
  const InventoryDetailPage({
    super.key,
    required this.item,
    required this.controller,
    required this.canAdjustInventory,
  });

  final InventoryItem item;
  final InventoryController controller;
  final bool canAdjustInventory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: SafeArea(
        child: InventoryDetailView(
          item: item,
          controller: controller,
          canAdjustInventory: canAdjustInventory,
        ),
      ),
    );
  }
}
