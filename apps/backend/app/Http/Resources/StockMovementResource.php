<?php

namespace App\Http\Resources;

use App\Models\StockMovement;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin StockMovement */
class StockMovementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => $this->id, 'inventory_item_id' => $this->inventory_item_id,
            'order_id' => $this->order_id, 'actor_id' => $this->actor_id, 'quantity_delta' => $this->quantity_delta,
            'reason' => $this->reason, 'note' => $this->note, 'created_at' => $this->created_at?->toIso8601String()];
    }
}
