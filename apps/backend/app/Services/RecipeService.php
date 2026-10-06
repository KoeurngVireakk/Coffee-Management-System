<?php

namespace App\Services;

use App\Inventory\Quantity;
use App\Models\InventoryItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\ValidationException;

class RecipeService
{
    public function read(Product $target): array
    {
        return DB::transaction(function () use ($target): array {
            Product::query()->whereKey($target->id)->sharedLock()->firstOrFail();

            return $this->snapshot($target->id);
        }, 3);
    }

    public function replace(User $actor, Product $target, array $ingredients): array
    {
        Gate::forUser($actor)->authorize('manage-catalog');
        $rows = [];
        if (count($ingredients) > 100 || ! array_is_list($ingredients)) {
            throw ValidationException::withMessages(['ingredients' => 'Provide at most 100 recipe ingredients.']);
        }
        foreach ($ingredients as $index => $ingredient) {
            if (! is_array($ingredient) || array_diff(array_keys($ingredient), ['inventory_item_id', 'quantity'])
                || ! is_int($ingredient['inventory_item_id'] ?? null) || $ingredient['inventory_item_id'] < 1
                || isset($rows[$ingredient['inventory_item_id']])) {
                throw ValidationException::withMessages(['ingredients' => 'Recipe ingredient identifiers must be unique positive integers.']);
            }
            try {
                $quantity = Quantity::parse($ingredient['quantity'] ?? null);
            } catch (\InvalidArgumentException) {
                throw ValidationException::withMessages(["ingredients.$index.quantity" => 'Provide an exact quantity string with at most four decimal places.']);
            }
            if ($quantity <= 0) {
                throw ValidationException::withMessages(["ingredients.$index.quantity" => 'Recipe quantity must be positive.']);
            }
            $rows[$ingredient['inventory_item_id']] = Quantity::format($quantity);
        }
        ksort($rows, SORT_NUMERIC);

        return DB::transaction(function () use ($actor, $target, $rows): array {
            Product::query()->whereKey($target->id)->lockForUpdate()->firstOrFail();
            Gate::forUser($actor)->authorize('manage-catalog');
            foreach ($rows as $id => $quantity) {
                $item = InventoryItem::query()->whereKey($id)->sharedLock()->first();
                if (! $item || ! $item->is_active) {
                    throw ValidationException::withMessages(['ingredients' => 'Every recipe ingredient must reference an active inventory item.']);
                }
            }
            DB::table('product_ingredients')->where('product_id', $target->id)->delete();
            if ($rows !== []) {
                DB::table('product_ingredients')->insert(array_map(
                    fn (int $id, string $quantity): array => ['product_id' => $target->id, 'inventory_item_id' => $id, 'quantity' => $quantity],
                    array_keys($rows), array_values($rows),
                ));
            }

            return $this->snapshot($target->id);
        }, 3);
    }

    private function snapshot(int $productId): array
    {
        $rows = DB::table('product_ingredients as recipe')->join('inventory_items as inventory', 'inventory.id', '=', 'recipe.inventory_item_id')
            ->where('recipe.product_id', $productId)->orderBy('recipe.inventory_item_id')
            ->get(['recipe.inventory_item_id', 'recipe.quantity', 'inventory.sku', 'inventory.name', 'inventory.base_unit', 'inventory.is_active']);

        return ['product_id' => $productId, 'ingredients' => $rows->map(fn (object $row): array => [
            'inventory_item_id' => (int) $row->inventory_item_id, 'sku' => $row->sku, 'name' => $row->name,
            'base_unit' => $row->base_unit, 'is_active' => (bool) $row->is_active,
            'quantity' => Quantity::format(Quantity::parse((string) $row->quantity)),
        ])->all()];
    }
}
