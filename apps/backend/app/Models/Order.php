<?php

namespace App\Models;

use App\Enums\OrderStatus;
use Database\Factories\OrderFactory;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use LogicException;

#[Hidden(['checkout_key', 'request_hash'])]
class Order extends Model
{
    /** @use HasFactory<OrderFactory> */
    use HasFactory;

    public const int MAX_LINES = 50;

    public const int MAX_QUANTITY = 99;

    public const int MAX_SUBTOTAL_MINOR = 4949995050;

    protected function casts(): array
    {
        return ['status' => OrderStatus::class, 'subtotal_minor' => 'integer', 'discount_minor' => 'integer',
            'tax_minor' => 'integer', 'total_minor' => 'integer', 'inventory_tracked' => 'boolean'];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Order mutations require a future approved lifecycle workflow.'));
        static::deleting(fn () => throw new LogicException('Order history cannot be deleted.'));
    }

    /** @return BelongsTo<User, $this> */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** @return HasMany<OrderItem, $this> */
    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class)->orderBy('line_number');
    }

    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        return $user->can('view-all-orders') ? $query : $query->where('created_by', $user->id);
    }
}
