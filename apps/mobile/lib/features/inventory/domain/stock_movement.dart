import 'package:flutter/foundation.dart';

import 'exact_quantity.dart';

/// Supported reasons for stock ledger movements.
enum StockMovementReason {
  openingBalance('opening_balance', 'Opening Balance'),
  receipt('receipt', 'Stock Receipt'),
  waste('waste', 'Waste / Spoilage'),
  adjustment('adjustment', 'Manual Adjustment'),
  sale('sale', 'Sale (POS)');

  const StockMovementReason(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static StockMovementReason parse(String raw) {
    for (final reason in StockMovementReason.values) {
      if (reason.wireValue == raw) return reason;
    }
    throw FormatException('Invalid stock movement reason: "$raw"');
  }

  static StockMovementReason? tryParse(String? raw) {
    if (raw == null) return null;
    for (final reason in StockMovementReason.values) {
      if (reason.wireValue == raw) return reason;
    }
    return null;
  }

  /// Whether this reason is permitted for manual operator submission.
  bool get isManual => this != StockMovementReason.sale;
}

/// Immutable record from the append-only stock movement ledger.
@immutable
class StockMovement {
  StockMovement({
    required this.id,
    required this.inventoryItemId,
    this.orderId,
    this.actorId,
    required this.quantityDelta,
    required this.reason,
    this.note,
    this.createdAt,
  }) {
    if (id <= 0) throw ArgumentError('Invalid movement ID: $id');
    if (inventoryItemId <= 0) {
      throw ArgumentError('Invalid inventory item ID: $inventoryItemId');
    }
    if (quantityDelta.isZero) {
      throw ArgumentError('Movement quantity delta cannot be zero.');
    }
  }

  final int id;
  final int inventoryItemId;
  final int? orderId;
  final int? actorId;
  final ExactQuantity quantityDelta;
  final StockMovementReason reason;
  final String? note;
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMovement &&
          other.id == id &&
          other.inventoryItemId == inventoryItemId &&
          other.orderId == orderId &&
          other.actorId == actorId &&
          other.quantityDelta == quantityDelta &&
          other.reason == reason &&
          other.note == note &&
          other.createdAt == createdAt);

  @override
  int get hashCode => Object.hash(
    id,
    inventoryItemId,
    orderId,
    actorId,
    quantityDelta,
    reason,
    note,
    createdAt,
  );

  @override
  String toString() =>
      'StockMovement(id: $id, item: $inventoryItemId, delta: ${quantityDelta.toCanonicalString()}, reason: ${reason.wireValue})';
}

/// Validated immutable intent for creating a new manual stock movement.
///
/// Enforces business rules and idempotency key safety before network submission.
@immutable
class StockMovementIntent {
  StockMovementIntent({
    required this.inventoryItemId,
    required this.reason,
    required this.quantityDelta,
    this.note,
    required this.idempotencyKey,
  }) {
    if (inventoryItemId <= 0) {
      throw ArgumentError('Invalid inventory item ID: $inventoryItemId');
    }
    if (!reason.isManual) {
      throw ArgumentError(
        'Cannot manually submit system movement reason: ${reason.wireValue}',
      );
    }
    if (quantityDelta.isZero) {
      throw ArgumentError('Movement quantity delta cannot be zero.');
    }

    // Direction business rules
    switch (reason) {
      case StockMovementReason.openingBalance:
      case StockMovementReason.receipt:
        if (!quantityDelta.isPositive) {
          throw ArgumentError(
            '${reason.label} requires a positive quantity delta.',
          );
        }
        break;
      case StockMovementReason.waste:
        if (!quantityDelta.isNegative) {
          throw ArgumentError('Waste requires a negative quantity delta.');
        }
        break;
      case StockMovementReason.adjustment:
        if (note == null || note!.trim().isEmpty) {
          throw ArgumentError('Adjustment requires an explanatory note.');
        }
        break;
      case StockMovementReason.sale:
        break;
    }

    if (note != null && note!.trim().length > 500) {
      throw ArgumentError('Note exceeds maximum length of 500 characters.');
    }

    validateIdempotencyKey(idempotencyKey);
  }

  final int inventoryItemId;
  final StockMovementReason reason;
  final ExactQuantity quantityDelta;
  final String? note;
  final String idempotencyKey;

  /// Validates standard 8-64 ASCII alphanumeric/._- idempotency key format.
  static void validateIdempotencyKey(String key) {
    if (RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{7,63}$').stringMatch(key) != key) {
      throw ArgumentError(
        'Invalid Idempotency-Key. Must be 8-64 ASCII characters starting with alphanumeric.',
      );
    }
  }

  /// Serializes intent into JSON payload for `POST /api/v1/inventory/items/{id}/movements`.
  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'reason': reason.wireValue,
      'quantity_delta': quantityDelta.toCanonicalString(),
    };
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      payload['note'] = trimmedNote;
    }
    return payload;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StockMovementIntent &&
          other.inventoryItemId == inventoryItemId &&
          other.reason == reason &&
          other.quantityDelta == quantityDelta &&
          other.note == note &&
          other.idempotencyKey == idempotencyKey);

  @override
  int get hashCode =>
      Object.hash(inventoryItemId, reason, quantityDelta, note, idempotencyKey);
}
