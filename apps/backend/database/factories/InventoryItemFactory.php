<?php

namespace Database\Factories;

use App\Models\InventoryItem;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<InventoryItem> */
class InventoryItemFactory extends Factory
{
    public function definition(): array
    {
        return ['sku' => 'INV-'.Str::upper(Str::random(12)), 'name' => fake()->words(2, true), 'base_unit' => 'g',
            'on_hand' => '0.0000', 'reserved' => '0.0000', 'reorder_level' => '0.0000', 'is_active' => true];
    }

    public function inactive(): static
    {
        return $this->state(fn () => ['is_active' => false]);
    }
}
