<?php

namespace Database\Factories;

use App\Models\Order;
use App\Models\Payment;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/** @extends Factory<Payment> */
class PaymentFactory extends Factory
{
    public function definition(): array
    {
        return ['order_id' => Order::factory(), 'attempt_key' => (string) Str::uuid(), 'request_hash' => hash('sha256', 'synthetic-cash-intent'),
            'method' => 'cash', 'status' => 'confirmed', 'expected_amount_minor' => 325, 'currency' => 'USD',
            'tender_minor' => 500, 'change_minor' => 175, 'reconciliation_required' => false, 'verified_at' => now()];
    }
}
