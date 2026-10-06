<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

/** Composite-key recipe rows are replaced by the product recipe workflow, never individually edited. */
class ProductIngredient extends Model
{
    public $timestamps = false;

    public $incrementing = false;

    protected $primaryKey = null;

    protected function casts(): array
    {
        return ['product_id' => 'integer', 'inventory_item_id' => 'integer', 'quantity' => 'decimal:4'];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Replace recipes through the recipe workflow.'));
        static::deleting(fn () => throw new LogicException('Replace recipes through the recipe workflow.'));
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    public function inventoryItem(): BelongsTo
    {
        return $this->belongsTo(InventoryItem::class);
    }
}
