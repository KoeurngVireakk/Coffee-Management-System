<?php

namespace App\Models;

use Database\Factories\OrderItemFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

class OrderItem extends Model
{
    /** @use HasFactory<OrderItemFactory> */
    use HasFactory;

    public $timestamps = false;

    protected function casts(): array
    {
        return ['unit_price_minor' => 'integer', 'quantity' => 'integer', 'subtotal_minor' => 'integer',
            'discount_minor' => 'integer', 'tax_minor' => 'integer', 'line_total_minor' => 'integer'];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Order item snapshots are immutable.'));
        static::deleting(fn () => throw new LogicException('Order item history cannot be deleted.'));
    }

    /** @return BelongsTo<Order, $this> */
    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    /** @return BelongsTo<Product, $this> */
    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
