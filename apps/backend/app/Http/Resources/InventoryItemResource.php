<?php

namespace App\Http\Resources;

use App\Inventory\Quantity;
use App\Models\InventoryItem;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin InventoryItem */
class InventoryItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $onHand = Quantity::parse($this->on_hand);
        $reserved = Quantity::parse($this->reserved);
        $available = Quantity::subtract($onHand, $reserved);

        return ['id' => $this->id, 'sku' => $this->sku, 'name' => $this->name, 'base_unit' => $this->base_unit,
            'on_hand' => Quantity::format($onHand), 'reserved' => Quantity::format($reserved),
            'available' => Quantity::format($available), 'reorder_level' => $this->reorder_level,
            'is_active' => $this->is_active, 'low_stock' => $available <= Quantity::parse($this->reorder_level),
            'created_at' => $this->created_at?->toIso8601String(), 'updated_at' => $this->updated_at?->toIso8601String()];
    }
}
