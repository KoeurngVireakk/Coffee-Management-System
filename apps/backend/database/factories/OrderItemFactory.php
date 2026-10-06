<?php

namespace Database\Factories;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<OrderItem> */
class OrderItemFactory extends Factory
{
    public function definition(): array
    {
        return ['order_id' => Order::factory(), 'product_id' => Product::factory(), 'line_number' => 1,
            'product_name' => 'Synthetic historical coffee', 'product_sku' => 'HISTORICAL-01',
            'unit_price_minor' => 325, 'quantity' => 1, 'subtotal_minor' => 325, 'discount_minor' => 0,
            'tax_minor' => 0, 'line_total_minor' => 325];
    }
}
