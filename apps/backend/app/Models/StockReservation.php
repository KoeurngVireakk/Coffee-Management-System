<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\DB;
use LogicException;

class StockReservation extends Model
{
    public $incrementing = false;

    protected $primaryKey = null;

    protected function casts(): array
    {
        return ['order_id' => 'integer', 'inventory_item_id' => 'integer', 'quantity' => 'decimal:4'];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Reservation facts are immutable; transitions require the owning workflow.'));
        static::deleting(fn () => throw new LogicException('Reservation history cannot be deleted.'));
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function inventoryItem(): BelongsTo
    {
        return $this->belongsTo(InventoryItem::class);
    }

    /** Owning order and sorted inventory locks must already be held. */
    public function transitionTo(string $status): void
    {
        if (DB::transactionLevel() < 1 || ! $this->exists || $this->getRawOriginal('status') !== 'reserved'
            || ! in_array($status, ['consumed', 'released'], true) || $this->isDirty()) {
            throw new LogicException('Reservation can transition from reserved to a terminal state only in its owning transaction.');
        }
        $changed = DB::table('stock_reservations')->where('order_id', $this->order_id)
            ->where('inventory_item_id', $this->inventory_item_id)->where('status', 'reserved')
            ->where('quantity', $this->getRawOriginal('quantity'))
            ->update(['status' => $status, 'updated_at' => now()]);
        if ($changed !== 1) {
            throw new LogicException('Reservation changed concurrently.');
        }
        $fresh = DB::table('stock_reservations')->where('order_id', $this->order_id)
            ->where('inventory_item_id', $this->inventory_item_id)->first();
        $this->setRawAttributes((array) $fresh, true);
    }
}
