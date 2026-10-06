<?php

namespace Database\Factories;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<Order> */
class OrderFactory extends Factory
{
    public function definition(): array
    {
        return ['public_reference' => 'ORD-'.Str::ulid(), 'created_by' => User::factory(),
            'status' => OrderStatus::PendingPayment, 'currency' => 'USD', 'subtotal_minor' => 325,
            'discount_minor' => 0, 'tax_minor' => 0, 'total_minor' => 325,
            'checkout_key' => (string) Str::uuid(), 'request_hash' => hash('sha256', 'synthetic-factory-intent'),
            'inventory_tracked' => false];
    }
}
