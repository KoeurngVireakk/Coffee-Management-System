<?php

namespace App\Http\Resources;

use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Order */
class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['public_reference' => $this->public_reference, 'status' => $this->status->value,
            'currency' => $this->currency, 'subtotal_minor' => (string) $this->subtotal_minor,
            'discount_minor' => (string) $this->discount_minor, 'tax_minor' => (string) $this->tax_minor,
            'total_minor' => (string) $this->total_minor, 'inventory_tracked' => $this->inventory_tracked,
            'created_at' => $this->created_at?->toIso8601String(),
            'creator' => ['id' => $this->creator->id, 'name' => $this->creator->name],
            'items' => OrderItemResource::collection($this->items),
            'accepted_payment' => $this->when($this->accepted_payment_id !== null,
                fn () => new PaymentResource($this->acceptedPayment)),
            'paid_at' => $this->when($this->paid_at !== null, fn () => $this->paid_at->toIso8601String())];
    }
}
