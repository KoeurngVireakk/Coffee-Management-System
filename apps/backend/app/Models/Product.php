<?php

namespace App\Models;

use Database\Factories\ProductFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['category_id', 'sku', 'name', 'description', 'price_minor', 'currency', 'is_active'])]
class Product extends Model
{
    /** @use HasFactory<ProductFactory> */
    use HasFactory;

    public const string CURRENCY = 'USD';

    public const int MINOR_UNIT_SCALE = 2;

    public const int MAX_PRICE_MINOR = 999999;

    protected function casts(): array
    {
        return ['price_minor' => 'integer', 'is_active' => 'boolean'];
    }

    /** @return BelongsTo<Category, $this> */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function scopeSellable(Builder $query): Builder
    {
        return $query->where('is_active', true)->whereHas('category', fn (Builder $category) => $category->active());
    }

    public function isSellable(): bool
    {
        return $this->is_active && $this->category->is_active;
    }
}
