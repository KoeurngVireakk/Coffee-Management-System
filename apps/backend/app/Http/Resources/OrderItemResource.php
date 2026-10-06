<?php

namespace App\Http\Resources;

use App\Models\OrderItem;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin OrderItem */
class OrderItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['line_number' => $this->line_number, 'product_id' => $this->product_id,
            'product_name' => $this->product_name, 'product_sku' => $this->product_sku,
            'unit_price_minor' => (string) $this->unit_price_minor, 'quantity' => $this->quantity,
            'subtotal_minor' => (string) $this->subtotal_minor, 'discount_minor' => (string) $this->discount_minor,
            'tax_minor' => (string) $this->tax_minor, 'line_total_minor' => (string) $this->line_total_minor];
    }
}
