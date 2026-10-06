<?php

namespace App\Http\Resources;

use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Product */
class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'category_id' => $this->category_id,
            'category' => ['id' => $this->category->id, 'name' => $this->category->name, 'is_active' => $this->category->is_active],
            'sku' => $this->sku,
            'name' => $this->name,
            'description' => $this->description,
            'price_minor' => (string) $this->price_minor,
            'currency' => $this->currency,
            'is_active' => $this->is_active,
            'is_sellable' => $this->isSellable(),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
