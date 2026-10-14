import 'package:flutter/foundation.dart';

import 'exact_quantity.dart';

/// Supported immutable base measurement units for inventory items.
enum BaseUnit {
  g('g', 'Grams'),
  ml('ml', 'Milliliters'),
  unit('unit', 'Units');

  const BaseUnit(this.value, this.label);

  final String value;
  final String label;

  static BaseUnit parse(String raw) {
    for (final unit in BaseUnit.values) {
      if (unit.value == raw) return unit;
    }
    throw FormatException('Invalid base unit: "$raw"');
  }

  static BaseUnit? tryParse(String? raw) {
    if (raw == null) return null;
    for (final unit in BaseUnit.values) {
      if (unit.value == raw) return unit;
    }
    return null;
  }
}

/// Authoritative inventory item entity.
///
/// Balances are server-managed exact DECIMAL(14,4) values.
@immutable
class InventoryItem {
  InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.baseUnit,
    required this.onHand,
    required this.reserved,
    required this.available,
    required this.reorderLevel,
    required this.isActive,
    required this.lowStock,
    this.createdAt,
    this.updatedAt,
  }) {
    if (id <= 0) {
      throw ArgumentError('Invalid item ID: $id');
    }
    if (sku.trim().isEmpty || sku.length > 64) {
      throw ArgumentError('Invalid SKU: "$sku"');
    }
    if (name.trim().isEmpty || name.length > 160) {
      throw ArgumentError('Invalid name: "$name"');
    }
  }

  final int id;
  final String sku;
  final String name;
  final BaseUnit baseUnit;
  final ExactQuantity onHand;
  final ExactQuantity reserved;
  final ExactQuantity available;
  final ExactQuantity reorderLevel;
  final bool isActive;
  final bool lowStock;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Creates a copy of this item with modified properties.
  InventoryItem copyWith({
    int? id,
    String? sku,
    String? name,
    BaseUnit? baseUnit,
    ExactQuantity? onHand,
    ExactQuantity? reserved,
    ExactQuantity? available,
    ExactQuantity? reorderLevel,
    bool? isActive,
    bool? lowStock,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      baseUnit: baseUnit ?? this.baseUnit,
      onHand: onHand ?? this.onHand,
      reserved: reserved ?? this.reserved,
      available: available ?? this.available,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      isActive: isActive ?? this.isActive,
      lowStock: lowStock ?? this.lowStock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryItem &&
          other.id == id &&
          other.sku == sku &&
          other.name == name &&
          other.baseUnit == baseUnit &&
          other.onHand == onHand &&
          other.reserved == reserved &&
          other.available == available &&
          other.reorderLevel == reorderLevel &&
          other.isActive == isActive &&
          other.lowStock == lowStock &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(
    id,
    sku,
    name,
    baseUnit,
    onHand,
    reserved,
    available,
    reorderLevel,
    isActive,
    lowStock,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'InventoryItem(id: $id, sku: $sku, name: $name, available: ${available.toCanonicalString()} ${baseUnit.value})';
}
