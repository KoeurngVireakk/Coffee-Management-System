<?php

namespace Database\Factories;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<Product> */
class ProductFactory extends Factory
{
    public function definition(): array
    {
        return [
            'category_id' => Category::factory(),
            'sku' => 'SKU-'.Str::upper(Str::random(12)),
            'name' => fake()->words(2, true),
            'description' => null,
            'price_minor' => fake()->numberBetween(50, 1500),
            'currency' => Product::CURRENCY,
            'is_active' => true,
        ];
    }

    public function inactive(): static
    {
        return $this->state(fn () => ['is_active' => false]);
    }
}
