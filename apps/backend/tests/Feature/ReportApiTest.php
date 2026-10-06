<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Enums\StaffRole;
use App\Models\InventoryItem;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Setting;
use App\Models\User;
use App\Settings\SettingRegistry;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class ReportApiTest extends TestCase
{
    use RefreshDatabase;

    private function staff(StaffRole $role = StaffRole::Manager): User
    {
        $user = User::factory()->withRole($role)->create();
        Auth::forgetGuards();
        $this->withToken($user->createToken('Synthetic report terminal', ['staff'], now()->addHour())->plainTextToken);

        return $user;
    }

    private function configureTimezone(string $timezone = 'UTC'): void
    {
        Setting::query()->updateOrCreate(
            ['key' => SettingRegistry::SHOP_TIMEZONE],
            ['value' => $timezone]
        );
    }

    private function createPaidOrder(
        int $totalMinor = 325,
        string $method = 'cash',
        ?\DateTimeInterface $paidAt = null,
        ?User $creator = null,
        array $items = []
    ): Order {
        $paidAt = $paidAt ? CarbonImmutable::instance($paidAt) : CarbonImmutable::now('UTC');
        $creator = $creator ?? User::factory()->create();

        $order = Order::factory()->create([
            'created_by' => $creator->id,
            'total_minor' => $totalMinor,
            'subtotal_minor' => $totalMinor,
            'discount_minor' => 0,
            'tax_minor' => 0,
            'currency' => 'USD',
            'status' => OrderStatus::PendingPayment,
            'paid_at' => null,
            'accepted_payment_id' => null,
            'active_payment_id' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        $paymentData = [
            'order_id' => $order->id,
            'initiated_by' => $creator->id,
            'attempt_key' => (string) Str::uuid(),
            'request_hash' => hash('sha256', (string) Str::uuid()),
            'method' => $method,
            'status' => PaymentStatus::Confirmed->value,
            'expected_amount_minor' => $totalMinor,
            'currency' => 'USD',
            'reconciliation_required' => false,
            'verified_at' => $paidAt,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ];

        if ($method === 'cash') {
            $paymentData['tender_minor'] = $totalMinor + 100;
            $paymentData['change_minor'] = 100;
        } else {
            $paymentData['tender_minor'] = null;
            $paymentData['change_minor'] = null;
            $paymentData['provider'] = 'bakong';
            $paymentData['external_transaction_id'] = 'ext-'.Str::uuid();
            $paymentData['correlation_reference'] = 'corr-'.Str::uuid();
            $paymentData['merchant_reference'] = 'merch-'.Str::uuid();
        }

        $payment = new Payment;
        $payment->forceFill($paymentData)->save();

        DB::table('orders')->where('id', $order->id)->update([
            'status' => OrderStatus::Paid->value,
            'accepted_payment_id' => $payment->id,
            'paid_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        if (! empty($items)) {
            foreach ($items as $idx => $itemData) {
                $quantity = $itemData['quantity'] ?? 1;
                $unitPriceMinor = $itemData['unit_price_minor'] ?? (int) ($itemData['line_total_minor'] / $quantity);
                $subtotalMinor = $unitPriceMinor * $quantity;
                $lineTotalMinor = $subtotalMinor;

                $item = new OrderItem;
                $item->forceFill([
                    'order_id' => $order->id,
                    'line_number' => $idx + 1,
                    'product_id' => $itemData['product_id'],
                    'product_name' => $itemData['product_name'] ?? 'Product '.$itemData['product_id'],
                    'product_sku' => $itemData['product_sku'] ?? 'SKU-'.$itemData['product_id'],
                    'unit_price_minor' => $unitPriceMinor,
                    'quantity' => $quantity,
                    'subtotal_minor' => $subtotalMinor,
                    'discount_minor' => 0,
                    'tax_minor' => 0,
                    'line_total_minor' => $lineTotalMinor,
                ])->save();
            }
        }

        return $order->fresh(['acceptedPayment', 'items']);
    }

    public function test_overview_with_no_sales_returns_zero_metrics(): void
    {
        $this->configureTimezone('UTC');
        $this->staff(StaffRole::Manager);

        $response = $this->getJson('/api/v1/reports/overview?from_date=2026-10-01&to_date=2026-10-05')
            ->assertOk();

        $response->assertJson([
            'data' => [
                'period' => [
                    'from_date' => '2026-10-01',
                    'to_date' => '2026-10-05',
                    'timezone' => 'UTC',
                ],
                'revenue_minor' => '0',
                'currency' => 'USD',
                'paid_orders' => 0,
                'average_order_value_minor' => '0',
                'low_stock_items' => 0,
                'reconciliation_required' => 0,
            ],
        ]);
    }

    public function test_overview_aggregates_paid_sales_and_excludes_unpaid_or_out_of_range(): void
    {
        $this->configureTimezone('UTC');
        $this->staff(StaffRole::Admin);

        // Within range: 2 paid orders ($10.00 and $20.50 -> 1000 + 2050 = 3050 minor)
        $this->createPaidOrder(1000, 'cash', CarbonImmutable::parse('2026-10-02 10:00:00 UTC'));
        $this->createPaidOrder(2050, 'external', CarbonImmutable::parse('2026-10-04 15:30:00 UTC'));

        // Outside range: paid order before range
        $this->createPaidOrder(5000, 'cash', CarbonImmutable::parse('2026-09-30 23:59:59 UTC'));

        // Outside range: paid order after range
        $this->createPaidOrder(5000, 'cash', CarbonImmutable::parse('2026-10-06 00:00:00 UTC'));

        // Unpaid order inside range
        Order::factory()->create([
            'status' => OrderStatus::PendingPayment,
            'subtotal_minor' => 9999,
            'discount_minor' => 0,
            'tax_minor' => 0,
            'total_minor' => 9999,
            'created_at' => CarbonImmutable::parse('2026-10-03 12:00:00 UTC'),
        ]);

        // Inventory items
        InventoryItem::factory()->create(['on_hand' => '10.0000', 'reserved' => '0.0000', 'reorder_level' => '15.0000', 'is_active' => true]); // low
        InventoryItem::factory()->create(['on_hand' => '50.0000', 'reserved' => '0.0000', 'reorder_level' => '10.0000', 'is_active' => true]); // not low
        InventoryItem::factory()->create(['on_hand' => '5.0000', 'reserved' => '0.0000', 'reorder_level' => '10.0000', 'is_active' => false]); // inactive low (not counted)

        // Reconciliation exception payment
        $order = Order::factory()->create();
        $payment = new Payment;
        $payment->forceFill([
            'order_id' => $order->id,
            'attempt_key' => (string) Str::uuid(),
            'request_hash' => hash('sha256', 'recon-hash'),
            'method' => 'external',
            'status' => PaymentStatus::Uncertain->value,
            'expected_amount_minor' => 1500,
            'currency' => 'USD',
            'reconciliation_required' => true,
            'reconciliation_reason' => 'timeout_uncertain',
        ])->save();

        $response = $this->getJson('/api/v1/reports/overview?from_date=2026-10-01&to_date=2026-10-05')
            ->assertOk();

        // 3050 minor / 2 paid orders = 1525 AOV
        $response->assertJson([
            'data' => [
                'revenue_minor' => '3050',
                'currency' => 'USD',
                'paid_orders' => 2,
                'average_order_value_minor' => '1525',
                'low_stock_items' => 1,
                'reconciliation_required' => 1,
            ],
        ]);
    }

    public function test_sales_trend_returns_consecutive_days_with_zero_filled_empty_days(): void
    {
        $this->configureTimezone('UTC');
        $this->staff(StaffRole::Manager);

        $this->createPaidOrder(1200, 'cash', CarbonImmutable::parse('2026-10-02 10:00:00 UTC'));
        $this->createPaidOrder(800, 'cash', CarbonImmutable::parse('2026-10-02 14:00:00 UTC'));
        $this->createPaidOrder(3000, 'external', CarbonImmutable::parse('2026-10-04 09:00:00 UTC'));

        $response = $this->getJson('/api/v1/reports/sales-trend?from_date=2026-10-01&to_date=2026-10-04')
            ->assertOk();

        $data = $response->json('data');
        $this->assertCount(4, $data);

        $this->assertSame('2026-10-01', $data[0]['date']);
        $this->assertSame('0', $data[0]['revenue_minor']);
        $this->assertSame(0, $data[0]['paid_orders']);

        $this->assertSame('2026-10-02', $data[1]['date']);
        $this->assertSame('2000', $data[1]['revenue_minor']);
        $this->assertSame(2, $data[1]['paid_orders']);

        $this->assertSame('2026-10-03', $data[2]['date']);
        $this->assertSame('0', $data[2]['revenue_minor']);
        $this->assertSame(0, $data[2]['paid_orders']);

        $this->assertSame('2026-10-04', $data[3]['date']);
        $this->assertSame('3000', $data[3]['revenue_minor']);
        $this->assertSame(1, $data[3]['paid_orders']);
    }

    public function test_payment_methods_groups_accepted_payments_and_ignores_unaccepted_attempts(): void
    {
        $this->configureTimezone('UTC');
        $this->staff(StaffRole::Manager);

        $this->createPaidOrder(1500, 'cash', CarbonImmutable::parse('2026-10-02 10:00:00 UTC'));
        $this->createPaidOrder(2500, 'cash', CarbonImmutable::parse('2026-10-03 10:00:00 UTC'));
        $this->createPaidOrder(4000, 'external', CarbonImmutable::parse('2026-10-03 12:00:00 UTC'));

        // Failed or uncertain payment attempt on another order (not accepted)
        $unpaidOrder = Order::factory()->create();
        $payment = new Payment;
        $payment->forceFill([
            'order_id' => $unpaidOrder->id,
            'attempt_key' => (string) Str::uuid(),
            'request_hash' => hash('sha256', 'failed-attempt'),
            'method' => 'external',
            'status' => PaymentStatus::Failed->value,
            'expected_amount_minor' => 5000,
            'currency' => 'USD',
        ])->save();

        $response = $this->getJson('/api/v1/reports/payment-methods?from_date=2026-10-01&to_date=2026-10-05')
            ->assertOk();

        $data = $response->json('data');
        $this->assertCount(2, $data);

        // cash: 4000 minor, 2 orders; external: 4000 minor, 1 order
        $this->assertSame('USD', $response->json('currency'));
        $this->assertSame('4000', $data[0]['amount_minor']);
        $this->assertSame('4000', $data[1]['amount_minor']);

        $methods = collect($data)->pluck('method')->all();
        $this->assertContains('cash', $methods);
        $this->assertContains('external', $methods);
    }

    public function test_top_products_aggregates_line_items_by_revenue_and_honors_limit(): void
    {
        $this->configureTimezone('UTC');
        $this->staff(StaffRole::Manager);

        $prod1 = Product::factory()->create(['name' => 'Americano', 'sku' => 'AME-001']);
        $prod2 = Product::factory()->create(['name' => 'Latte', 'sku' => 'LAT-002']);
        $prod3 = Product::factory()->create(['name' => 'Espresso', 'sku' => 'ESP-003']);

        // Order 1: 2 Americanos ($6.00) + 1 Latte ($4.00) = $10.00
        $this->createPaidOrder(
            1000,
            'cash',
            CarbonImmutable::parse('2026-10-02 10:00:00 UTC'),
            null,
            [
                ['product_id' => $prod1->id, 'product_name' => 'Americano', 'product_sku' => 'AME-001', 'unit_price_minor' => 300, 'quantity' => 2, 'line_total_minor' => 600],
                ['product_id' => $prod2->id, 'product_name' => 'Latte', 'product_sku' => 'LAT-002', 'unit_price_minor' => 400, 'quantity' => 1, 'line_total_minor' => 400],
            ]
        );

        // Order 2: 3 Lattes ($12.00) + 1 Espresso ($2.50) = $14.50
        $this->createPaidOrder(
            1450,
            'external',
            CarbonImmutable::parse('2026-10-03 10:00:00 UTC'),
            null,
            [
                ['product_id' => $prod2->id, 'product_name' => 'Latte', 'product_sku' => 'LAT-002', 'unit_price_minor' => 400, 'quantity' => 3, 'line_total_minor' => 1200],
                ['product_id' => $prod3->id, 'product_name' => 'Espresso', 'product_sku' => 'ESP-003', 'unit_price_minor' => 250, 'quantity' => 1, 'line_total_minor' => 250],
            ]
        );

        // Latte: 4 sold, 1600 minor
        // Americano: 2 sold, 600 minor
        // Espresso: 1 sold, 250 minor

        $response = $this->getJson('/api/v1/reports/top-products?from_date=2026-10-01&to_date=2026-10-05&limit=2')
            ->assertOk();

        $data = $response->json('data');
        $this->assertCount(2, $data);

        $this->assertSame($prod2->id, $data[0]['product_id']);
        $this->assertSame('Latte', $data[0]['name']);
        $this->assertSame(4, $data[0]['quantity_sold']);
        $this->assertSame('1600', $data[0]['revenue_minor']);

        $this->assertSame($prod1->id, $data[1]['product_id']);
        $this->assertSame('Americano', $data[1]['name']);
        $this->assertSame(2, $data[1]['quantity_sold']);
        $this->assertSame('600', $data[1]['revenue_minor']);
    }

    public function test_inventory_report_returns_summary_and_filtered_paginated_items(): void
    {
        $this->configureTimezone('UTC');
        $this->staff(StaffRole::Manager);

        $item1 = InventoryItem::factory()->create([
            'sku' => 'COFFEE-BEANS',
            'name' => 'Arabica Coffee Beans',
            'base_unit' => 'g',
            'on_hand' => '1000.0000',
            'reserved' => '200.0000',
            'reorder_level' => '1500.0000', // available 800 <= 1500 -> LOW
            'is_active' => true,
        ]);

        $item2 = InventoryItem::factory()->create([
            'sku' => 'FRESH-MILK',
            'name' => 'Whole Milk',
            'base_unit' => 'ml',
            'on_hand' => '5000.0000',
            'reserved' => '0.0000',
            'reorder_level' => '2000.0000', // available 5000 > 2000 -> NOT LOW
            'is_active' => true,
        ]);

        $item3 = InventoryItem::factory()->create([
            'sku' => 'SUGAR-CANE',
            'name' => 'Cane Sugar Syrup',
            'base_unit' => 'ml',
            'on_hand' => '50.0000',
            'reserved' => '0.0000',
            'reorder_level' => '100.0000', // available 50 <= 100 -> LOW
            'is_active' => true,
        ]);

        // Inactive item with low stock
        InventoryItem::factory()->create([
            'sku' => 'OLD-TEA',
            'name' => 'Retired Tea Leaves',
            'base_unit' => 'g',
            'on_hand' => '0.0000',
            'reserved' => '0.0000',
            'reorder_level' => '10.0000',
            'is_active' => false,
        ]);

        // Default query (status=low)
        $responseLow = $this->getJson('/api/v1/reports/inventory?status=low')
            ->assertOk();

        $responseLow->assertJsonPath('summary.total_items', 4);
        $responseLow->assertJsonPath('summary.low_stock_items', 2);
        $this->assertCount(2, $responseLow->json('data'));

        // Query status=all
        $responseAll = $this->getJson('/api/v1/reports/inventory?status=all')
            ->assertOk();
        $this->assertCount(4, $responseAll->json('data'));

        // Query with search
        $responseSearch = $this->getJson('/api/v1/reports/inventory?status=all&search=Milk')
            ->assertOk();
        $this->assertCount(1, $responseSearch->json('data'));
        $this->assertSame($item2->sku, $responseSearch->json('data.0.sku'));

        // Check fields of an item
        $firstItem = $responseLow->json('data.0');
        $this->assertArrayHasKey('id', $firstItem);
        $this->assertArrayHasKey('sku', $firstItem);
        $this->assertArrayHasKey('name', $firstItem);
        $this->assertArrayHasKey('base_unit', $firstItem);
        $this->assertArrayHasKey('on_hand', $firstItem);
        $this->assertArrayHasKey('reserved', $firstItem);
        $this->assertArrayHasKey('available', $firstItem);
        $this->assertArrayHasKey('reorder_level', $firstItem);
        $this->assertArrayHasKey('is_low_stock', $firstItem);
        $this->assertArrayHasKey('is_active', $firstItem);
    }

    public function test_reconciliation_report_returns_exception_payments_with_safe_fields(): void
    {
        $this->configureTimezone('UTC');
        $this->staff(StaffRole::Manager);

        $order = Order::factory()->create();

        // 1. Confirmed cash payment (clean - should NOT appear in exceptions)
        $p1 = new Payment;
        $p1->forceFill([
            'order_id' => $order->id,
            'attempt_key' => (string) Str::uuid(),
            'request_hash' => hash('sha256', 'clean-attempt'),
            'method' => 'cash',
            'status' => PaymentStatus::Confirmed->value,
            'expected_amount_minor' => 325,
            'currency' => 'USD',
            'tender_minor' => 500,
            'change_minor' => 175,
            'reconciliation_required' => false,
            'verified_at' => now(),
        ])->save();

        // 2. External payment requiring reconciliation
        $p2 = new Payment;
        $p2->forceFill([
            'order_id' => $order->id,
            'attempt_key' => (string) Str::uuid(),
            'request_hash' => hash('sha256', 'recon-attempt'),
            'method' => 'external',
            'status' => PaymentStatus::Confirmed->value,
            'expected_amount_minor' => 1500,
            'currency' => 'USD',
            'provider' => 'bakong',
            'external_transaction_id' => 'tx-123',
            'correlation_reference' => 'corr-123',
            'merchant_reference' => 'merch-123',
            'reconciliation_required' => true,
            'reconciliation_reason' => 'amount_mismatch_settled_override',
            'verified_at' => now(),
        ])->save();

        // 3. Pending external payment
        $p3 = new Payment;
        $p3->forceFill([
            'order_id' => $order->id,
            'attempt_key' => (string) Str::uuid(),
            'request_hash' => hash('sha256', 'pending-attempt'),
            'method' => 'external',
            'status' => PaymentStatus::Pending->value,
            'expected_amount_minor' => 800,
            'currency' => 'USD',
            'reconciliation_required' => false,
        ])->save();

        $response = $this->getJson('/api/v1/reports/reconciliation')
            ->assertOk();

        $response->assertJsonPath('summary.reconciliation_required_count', 1);
        $response->assertJsonPath('summary.unresolved_attempts_count', 1);

        $data = $response->json('data');
        $this->assertCount(2, $data);

        // Verify secrets are NOT exposed
        foreach ($data as $item) {
            $this->assertArrayNotHasKey('attempt_key', $item);
            $this->assertArrayNotHasKey('request_hash', $item);
            $this->assertArrayNotHasKey('provider', $item);
            $this->assertArrayNotHasKey('external_transaction_id', $item);
            $this->assertArrayNotHasKey('merchant_reference', $item);
            $this->assertArrayNotHasKey('correlation_reference', $item);
            $this->assertArrayNotHasKey('qr_payload', $item);
            $this->assertArrayNotHasKey('initiated_by', $item);

            $this->assertArrayHasKey('id', $item);
            $this->assertArrayHasKey('order_id', $item);
            $this->assertArrayHasKey('order_reference', $item);
            $this->assertArrayHasKey('method', $item);
            $this->assertArrayHasKey('status', $item);
            $this->assertArrayHasKey('expected_amount_minor', $item);
            $this->assertArrayHasKey('currency', $item);
            $this->assertArrayHasKey('reconciliation_required', $item);
            $this->assertArrayHasKey('reconciliation_reason', $item);
        }
    }
}
