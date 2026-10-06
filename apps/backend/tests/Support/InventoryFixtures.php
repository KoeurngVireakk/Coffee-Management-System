<?php

namespace Tests\Support;

use App\Enums\StaffRole;
use App\Models\InventoryItem;
use App\Models\Product;
use App\Models\User;
use App\Services\OrderCheckoutService;
use App\Services\RecipeService;
use App\Services\StockMovementService;
use Illuminate\Support\Str;

trait InventoryFixtures
{
    private function inventory(string $opening = '100.0000', string $unit = 'g'): InventoryItem
    {
        $item = new InventoryItem;
        $item->forceFill(['sku' => 'TEST-'.Str::upper(Str::random(10)), 'name' => 'Synthetic stock',
            'base_unit' => $unit, 'reorder_level' => '0.0000', 'is_active' => true])->save();
        if ($opening !== '0.0000') {
            app(StockMovementService::class)->append(User::factory()->withRole(StaffRole::Manager)->create(), $item,
                ['reason' => 'opening_balance', 'quantity_delta' => $opening, 'note' => 'Synthetic initial stock'], 'opening-'.$item->id);
        }

        return $item->refresh();
    }

    private function recipe(array $ingredients): Product
    {
        $product = Product::factory()->create(['price_minor' => 325]);
        app(RecipeService::class)->replace(User::factory()->withRole(StaffRole::Manager)->create(), $product, $ingredients);

        return $product;
    }

    private function tracked(User $actor, Product $product, string $key = 'tracked-checkout-key', int $quantity = 1)
    {
        config(['inventory.tracking_enabled' => true]);

        return app(OrderCheckoutService::class)->checkout($actor, [['product_id' => $product->id, 'quantity' => $quantity]], $key);
    }
}
