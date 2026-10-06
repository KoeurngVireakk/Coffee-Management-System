<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

#[Hidden(['operation_key', 'attempt_key', 'request_hash'])]
class StockMovement extends Model
{
    public $timestamps = false;

    protected function casts(): array
    {
        return ['inventory_item_id' => 'integer', 'order_id' => 'integer', 'actor_id' => 'integer', 'quantity_delta' => 'decimal:4', 'created_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Stock movement history is append-only.'));
        static::deleting(fn () => throw new LogicException('Stock movement history cannot be deleted.'));
    }

    public function inventoryItem(): BelongsTo
    {
        return $this->belongsTo(InventoryItem::class);
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }
}
