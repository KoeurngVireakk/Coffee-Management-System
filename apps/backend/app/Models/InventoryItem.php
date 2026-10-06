<?php

namespace App\Models;

use App\Inventory\Quantity;
use Database\Factories\InventoryItemFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\DB;
use LogicException;

class InventoryItem extends Model
{
    /** @use HasFactory<InventoryItemFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return ['on_hand' => 'decimal:4', 'reserved' => 'decimal:4', 'reorder_level' => 'decimal:4', 'is_active' => 'boolean'];
    }

    protected static function booted(): void
    {
        static::updating(function (InventoryItem $item): void {
            if ($item->isDirty(['base_unit', 'on_hand', 'reserved', 'created_at'])) {
                throw new LogicException('Stock balances and base unit cannot be edited as item metadata.');
            }
        });
        static::deleting(fn () => throw new LogicException('Inventory history cannot be deleted; retire the item instead.'));
    }

    public function reservations(): HasMany
    {
        return $this->hasMany(StockReservation::class);
    }

    public function movements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }

    /** The owning workflow must hold the inventory row lock and update its ledger in this transaction. */
    public function writeBalances(mixed $onHand, mixed $reserved): void
    {
        if (! is_int($onHand) || ! is_int($reserved) || DB::transactionLevel() < 1 || ! $this->exists
            || $this->isDirty(['base_unit', 'on_hand', 'reserved']) || $onHand < 0 || $reserved < 0 || $reserved > $onHand) {
            throw new LogicException('Stock balance updates require a transaction and valid nonnegative balances.');
        }
        $values = ['on_hand' => Quantity::format($onHand), 'reserved' => Quantity::format($reserved)];
        $changed = DB::table('inventory_items')->where('id', $this->id)
            ->where('on_hand', $this->getRawOriginal('on_hand'))->where('reserved', $this->getRawOriginal('reserved'))
            ->update($values + ['updated_at' => now()]);
        if ($changed !== 1) {
            throw new LogicException('Stock balances changed concurrently.');
        }
        $this->refresh();
    }
}
