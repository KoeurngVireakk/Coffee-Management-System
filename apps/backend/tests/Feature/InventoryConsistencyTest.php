<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\CashPaymentService;
use App\Services\InventoryConsistencyService;
use App\Services\OrderCancellationService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Support\InventoryFixtures;
use Tests\TestCase;

class InventoryConsistencyTest extends TestCase
{
    use DatabaseMigrations, InventoryFixtures;

    public function test_audit_accepts_exact_pending_paid_and_cancelled_snapshots_and_command_is_read_only(): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '0.1234']]);
        $this->tracked($actor, $product, 'audit-pending-key');
        $paid = $this->tracked($actor, $product, 'audit-paid-key');
        app(CashPaymentService::class)->settle($actor, $paid, 325, 'audit-cash-key');
        $cancelled = $this->tracked($actor, $product, 'audit-cancel-key');
        app(OrderCancellationService::class)->cancel($actor, $cancelled);
        $before = $this->state();
        $report = app(InventoryConsistencyService::class)->audit();
        $this->assertSame(0, $report['finding_count']);
        $this->assertSame(1, $report['items_checked']);
        $this->assertSame(3, $report['orders_checked']);
        $this->artisan('inventory:check --json')->assertSuccessful();
        $this->assertSame($before, $this->state());
    }

    public static function corruptions(): array
    {
        return ['reserved sum' => ['reserved', 'reserved_balance_mismatch'], 'on hand ledger' => ['ledger', 'on_hand_ledger_mismatch'],
            'sale quantity' => ['sale', 'consumption_sale_mismatch'], 'reservation lifecycle' => ['lifecycle', 'reservation_order_state_mismatch'],
            'missing reservation' => ['missing', 'tracked_order_missing_reservations']];
    }

    #[DataProvider('corruptions')]
    public function test_corruption_is_reported_without_repair(string $mode, string $expectedCode): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $order = $this->tracked($actor, $product);
        if ($mode === 'sale' || $mode === 'lifecycle') {
            app(CashPaymentService::class)->settle($actor, $order, 325, 'audit-paid-corrupt');
        }
        // Deliberate raw SQL corruption simulates imports/operator mistakes outside workflow guards.
        match ($mode) {
            'reserved' => DB::table('inventory_items')->where('id', $stock->id)->update(['reserved' => '17.0000']),
            'ledger' => DB::table('inventory_items')->where('id', $stock->id)->update(['on_hand' => '99.0000']),
            'sale' => DB::table('stock_movements')->where('order_id', $order->id)->update(['quantity_delta' => '-17.0000']),
            'lifecycle' => DB::table('stock_reservations')->where('order_id', $order->id)->update(['status' => 'released']),
            'missing' => DB::table('stock_reservations')->where('order_id', $order->id)->delete(),
        };
        $before = $this->state();
        $report = app(InventoryConsistencyService::class)->audit();
        $this->assertContains($expectedCode, array_column($report['findings'], 'code'));
        $this->artisan('inventory:check')->assertFailed();
        $this->assertSame($before, $this->state());
    }

    private function state(): array
    {
        return [DB::table('inventory_items')->orderBy('id')->get()->toJson(), DB::table('stock_movements')->orderBy('id')->get()->toJson(),
            DB::table('stock_reservations')->orderBy('order_id')->orderBy('inventory_item_id')->get()->toJson(), DB::table('orders')->orderBy('id')->get()->toJson()];
    }
}
