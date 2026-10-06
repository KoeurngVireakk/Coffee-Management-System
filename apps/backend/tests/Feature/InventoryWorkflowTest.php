<?php

namespace Tests\Feature;

use App\Enums\PaymentStatus;
use App\Enums\StaffRole;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Payments\PaymentProvider;
use App\Services\CashPaymentService;
use App\Services\ExternalPaymentService;
use App\Services\OrderCancellationService;
use App\Services\OrderCheckoutService;
use App\Services\OrderSettlementService;
use App\Services\RecipeService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Tests\Support\FakePaymentProvider;
use Tests\Support\InventoryFixtures;
use Tests\TestCase;

class InventoryWorkflowTest extends TestCase
{
    use DatabaseMigrations, InventoryFixtures;

    private function staff(User $actor): void
    {
        Auth::forgetGuards();
        $this->withToken($actor->createToken('Synthetic inventory terminal', ['staff'], now()->addHour())->plainTextToken);
    }

    public function test_disabled_tracking_does_not_require_recipes_or_touch_stock_and_historical_order_still_settles(): void
    {
        $actor = User::factory()->create();
        $product = Product::factory()->create(['price_minor' => 325]);
        config(['inventory.tracking_enabled' => false]);
        $order = app(OrderCheckoutService::class)->checkout($actor, [['product_id' => $product->id, 'quantity' => 1]], 'before-inventory-key');
        $this->assertFalse($order->inventory_tracked);
        config(['inventory.tracking_enabled' => true]);
        app(CashPaymentService::class)->settle($actor, $order, 325, 'historical-cash-key');
        $this->assertSame('paid', $order->fresh()->status->value);
        $this->assertDatabaseCount('stock_reservations', 0);
        $this->assertDatabaseCount('stock_movements', 0);
        $this->assertFalse($order->fresh()->inventory_tracked);
    }

    public function test_checkout_aggregates_exact_shared_ingredients_and_replay_keeps_snapshot_after_recipe_changes(): void
    {
        $actor = User::factory()->create();
        $beans = $this->inventory();
        $milk = $this->inventory('500.0000', 'ml');
        $first = $this->recipe([['inventory_item_id' => $beans->id, 'quantity' => '0.1234'], ['inventory_item_id' => $milk->id, 'quantity' => '18.0000']]);
        $second = $this->recipe([['inventory_item_id' => $beans->id, 'quantity' => '1.0001']]);
        $intent = [['product_id' => $first->id, 'quantity' => 3], ['product_id' => $second->id, 'quantity' => 2]];
        config(['inventory.tracking_enabled' => true]);
        $order = app(OrderCheckoutService::class)->checkout($actor, $intent, 'aggregate-checkout-key');
        $this->assertTrue($order->inventory_tracked);
        $this->assertSame('2.3704', $beans->fresh()->reserved);
        $this->assertSame('54.0000', $milk->fresh()->reserved);
        $this->assertDatabaseCount('stock_reservations', 2);
        app(RecipeService::class)->replace(User::factory()->withRole(StaffRole::Manager)->create(), $first,
            [['inventory_item_id' => $beans->id, 'quantity' => '99.0000']]);
        $replay = app(OrderCheckoutService::class)->checkout($actor, $intent, 'aggregate-checkout-key');
        $this->assertSame($order->id, $replay->id);
        $this->assertSame('2.3704', $beans->fresh()->reserved);
        $this->assertSame('54.0000', $milk->fresh()->reserved);
        $this->assertDatabaseCount('orders', 1);
    }

    public static function invalidRequirements(): array
    {
        return ['missing recipe' => ['missing'], 'inactive stock' => ['inactive'], 'insufficient stock' => ['insufficient'], 'quantity overflow' => ['overflow']];
    }

    #[DataProvider('invalidRequirements')]
    public function test_invalid_tracked_requirements_leave_no_partial_order_or_reservation(string $mode): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory('1.0000');
        $product = $this->recipe($mode === 'missing' ? [] : [['inventory_item_id' => $stock->id, 'quantity' => $mode === 'overflow' ? '9999999999.9999' : '1.0000']]);
        if ($mode === 'inactive') {
            $stock->forceFill(['is_active' => false])->save();
        }
        try {
            $this->tracked($actor, $product, quantity: $mode === 'insufficient' || $mode === 'overflow' ? 2 : 1);
            $this->fail('Invalid tracked checkout succeeded.');
        } catch (ValidationException) {
            $this->assertDatabaseCount('orders', 0);
            $this->assertDatabaseCount('order_items', 0);
            $this->assertDatabaseCount('stock_reservations', 0);
            $this->assertSame('0.0000', $stock->fresh()->reserved);
        }
    }

    public function test_checkout_failure_after_first_reservation_rolls_back_all_rows_and_balances(): void
    {
        $actor = User::factory()->create();
        $one = $this->inventory();
        $two = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $one->id, 'quantity' => '1.0000'], ['inventory_item_id' => $two->id, 'quantity' => '2.0000']]);
        $inserted = 0;
        DB::connection()->beforeExecuting(function (string $sql) use (&$inserted): void {
            if (str_starts_with($sql, 'insert into') && str_contains($sql, 'stock_reservations') && ++$inserted === 2) {
                throw new RuntimeException('Synthetic second reservation failure.');
            }
        });
        try {
            $this->tracked($actor, $product);
            $this->fail('Injected checkout failure did not occur.');
        } catch (RuntimeException $error) {
            $this->assertSame('Synthetic second reservation failure.', $error->getMessage());
        }
        $this->assertDatabaseCount('orders', 0);
        $this->assertDatabaseCount('order_items', 0);
        $this->assertDatabaseCount('stock_reservations', 0);
        $this->assertSame('0.0000', $one->fresh()->reserved);
        $this->assertSame('0.0000', $two->fresh()->reserved);
    }

    public function test_cash_consumes_frozen_requirements_once_even_after_tracking_gate_is_disabled_and_stock_retired(): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.1234']]);
        $order = $this->tracked($actor, $product);
        $before = $order->items->sole()->getAttributes();
        $stock->forceFill(['is_active' => false])->save();
        config(['inventory.tracking_enabled' => false]);
        $payment = app(CashPaymentService::class)->settle($actor, $order, 500, 'tracked-cash-key');
        $replay = app(CashPaymentService::class)->settle($actor, $order, 500, 'tracked-cash-key');
        $this->assertSame($payment->id, $replay->id);
        $this->assertSame('81.8766', $stock->fresh()->on_hand);
        $this->assertSame('0.0000', $stock->fresh()->reserved);
        $this->assertDatabaseHas('stock_reservations', ['order_id' => $order->id, 'status' => 'consumed']);
        $this->assertDatabaseHas('stock_movements', ['order_id' => $order->id, 'reason' => 'sale', 'quantity_delta' => '-18.1234']);
        $this->assertSame(1, DB::table('stock_movements')->where('reason', 'sale')->count());
        $this->assertSame('paid', $order->fresh()->status->value);
        $this->assertSame($before, $order->items->sole()->fresh()->getAttributes());
    }

    public function test_verified_external_payment_consumes_once_and_second_transaction_only_flags_review(): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $order = $this->tracked($actor, $product);
        $provider = new FakePaymentProvider;
        $this->app->instance(PaymentProvider::class, $provider);
        $service = app(ExternalPaymentService::class);
        $payment = $service->initiate($actor, $order, 'tracked-external-key');
        $this->assertSame('18.0000', $stock->fresh()->reserved);
        $this->assertSame('100.0000', $stock->fresh()->on_hand);
        $service->reconcile($payment);
        $service->reconcile($payment);
        $provider->facts = ['transaction' => 'SYNTHETIC-ADDITIONAL-FUNDS'];
        $this->assertTrue($service->reconcile($payment)->reconciliation_required);
        $this->assertSame('82.0000', $stock->fresh()->on_hand);
        $this->assertSame('0.0000', $stock->fresh()->reserved);
        $this->assertSame(1, DB::table('stock_movements')->where('reason', 'sale')->count());
        $this->assertSame('paid', $order->fresh()->status->value);
    }

    public static function localFailures(): array
    {
        return ['cash sale insert' => ['cash', 'sale'], 'cash order transition' => ['cash', 'order'], 'external sale insert' => ['external', 'sale'], 'external order transition' => ['external', 'order'], 'cancel order transition' => ['cancel', 'order']];
    }

    #[DataProvider('localFailures')]
    public function test_local_failures_preserve_pending_reservations_and_roll_back_payment_evidence_stock_and_sales(string $mode, string $point): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $order = $this->tracked($actor, $product);
        $this->app->instance(PaymentProvider::class, new FakePaymentProvider);
        $external = $mode === 'external' ? app(ExternalPaymentService::class)->initiate($actor, $order, 'failure-external-key') : null;
        $failed = false;
        DB::connection()->beforeExecuting(function (string $sql) use ($point, &$failed): void {
            $normalized = str_replace(['`', '"'], '', $sql);
            if (! $failed && (($point === 'sale' && str_starts_with($sql, 'insert into') && str_contains($normalized, 'stock_movements'))
                || ($point === 'order' && str_starts_with($sql, 'update') && str_contains($normalized, 'orders') && str_contains($normalized, 'status')))) {
                $failed = true;
                throw new RuntimeException('Synthetic terminal failure.');
            }
        });
        try {
            match ($mode) {
                'cash' => app(CashPaymentService::class)->settle($actor, $order, 325, 'failure-cash-key'),
                'external' => app(ExternalPaymentService::class)->reconcile($external),
                'cancel' => app(OrderCancellationService::class)->cancel($actor, $order),
            };
            $this->fail('Injected terminal failure did not occur.');
        } catch (RuntimeException $error) {
            $this->assertSame('Synthetic terminal failure.', $error->getMessage());
        }
        $this->assertSame('pending_payment', $order->fresh()->status->value);
        $this->assertNull($order->fresh()->accepted_payment_id);
        $this->assertSame('100.0000', $stock->fresh()->on_hand);
        $this->assertSame('18.0000', $stock->fresh()->reserved);
        $this->assertDatabaseHas('stock_reservations', ['order_id' => $order->id, 'status' => 'reserved']);
        $this->assertSame(0, DB::table('stock_movements')->where('reason', 'sale')->count());
        $this->assertDatabaseCount('payment_evidence', 0);
        $this->assertDatabaseCount('payments', $mode === 'external' ? 1 : 0);
        if ($external) {
            $this->assertSame('pending', $external->fresh()->status->value);
        }
    }

    public function test_safe_cancellation_releases_once_without_on_hand_movement_and_rejects_bola_and_injection(): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $order = $this->tracked($actor, $product);
        $uri = '/api/v1/orders/'.$order->public_reference.'/cancel';
        $this->staff(User::factory()->create());
        $this->postJson($uri, [])->assertNotFound();
        $this->staff($actor);
        $this->postJson($uri, ['status' => 'cancelled', 'reserved' => '0.0000'])->assertUnprocessable();
        $this->postJson($uri, [])->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->postJson($uri, [])->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->assertSame('100.0000', $stock->fresh()->on_hand);
        $this->assertSame('0.0000', $stock->fresh()->reserved);
        $this->assertDatabaseHas('stock_reservations', ['order_id' => $order->id, 'status' => 'released']);
        $this->assertDatabaseCount('stock_movements', 1);
        $this->postJson('/api/v1/orders/'.$order->public_reference.'/payments/cash', ['tender_minor' => '325'], ['Idempotency-Key' => 'cash-cancelled-key'])->assertConflict();
    }

    public function test_untracked_manager_cancellation_and_paid_cancellation_denial_do_not_change_inventory(): void
    {
        $actor = User::factory()->create();
        $order = Order::factory()->create(['created_by' => $actor->id]);
        $this->staff(User::factory()->withRole(StaffRole::Manager)->create());
        $this->postJson('/api/v1/orders/'.$order->public_reference.'/cancel', [])->assertOk();
        $paid = Order::factory()->create(['created_by' => $actor->id]);
        app(CashPaymentService::class)->settle($actor, $paid, 325, 'paid-cannot-cancel');
        $this->postJson('/api/v1/orders/'.$paid->public_reference.'/cancel', [])->assertConflict();
        $this->assertDatabaseCount('stock_reservations', 0);
        $this->assertDatabaseCount('stock_movements', 0);
    }

    public function test_external_uncertainty_and_received_mismatch_block_release_but_trusted_failure_allows_safe_cancellation(): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $order = $this->tracked($actor, $product);
        $provider = new FakePaymentProvider;
        $provider->timeoutInitiation = true;
        $this->app->instance(PaymentProvider::class, $provider);
        $payment = app(ExternalPaymentService::class)->initiate($actor, $order, 'uncertain-tracked-key');
        $this->staff($actor);
        $uri = '/api/v1/orders/'.$order->public_reference.'/cancel';
        $this->postJson($uri, [])->assertConflict();
        $this->assertSame('18.0000', $stock->fresh()->reserved);
        $provider->status = PaymentStatus::Failed;
        app(ExternalPaymentService::class)->reconcile($payment);
        $this->postJson($uri, [])->assertOk();
        $provider->status = PaymentStatus::Confirmed;
        $late = app(ExternalPaymentService::class)->reconcile($payment);
        $this->assertTrue($late->reconciliation_required);
        $this->assertSame('cancelled', $order->fresh()->status->value);
        $this->assertSame('100.0000', $stock->fresh()->on_hand);
        $this->assertSame('0.0000', $stock->fresh()->reserved);
        $this->assertSame(0, DB::table('stock_movements')->where('reason', 'sale')->count());

        $second = $this->tracked($actor, $product, 'mismatch-tracked-key');
        $provider->timeoutInitiation = false;
        $attempt = app(ExternalPaymentService::class)->initiate($actor, $second, 'mismatch-external-key');
        $provider->facts = ['amount' => 326];
        app(ExternalPaymentService::class)->reconcile($attempt);
        $this->postJson('/api/v1/orders/'.$second->public_reference.'/cancel', [])->assertConflict();
        $this->assertSame('18.0000', $stock->fresh()->reserved);
    }

    public function test_missing_reservation_cannot_be_bypassed_by_direct_tracked_cash_payment(): void
    {
        $order = Order::factory()->create(['inventory_tracked' => true]);
        $this->staff($order->creator);
        $this->postJson('/api/v1/orders/'.$order->public_reference.'/payments/cash', ['tender_minor' => '325'], ['Idempotency-Key' => 'no-reservation-key'])->assertConflict();
        $this->assertSame('pending_payment', $order->fresh()->status->value);
        $this->assertDatabaseCount('payments', 0);
        $this->assertDatabaseCount('stock_movements', 0);
    }

    public function test_direct_finalizer_cannot_accept_quarantined_confirmed_payment_or_consume_stock(): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $order = $this->tracked($actor, $product);
        $provider = new FakePaymentProvider;
        $this->app->instance(PaymentProvider::class, $provider);
        $service = app(ExternalPaymentService::class);
        $attempt = $service->initiate($actor, $order, 'quarantined-direct-key');
        $provider->status = PaymentStatus::Failed;
        $service->reconcile($attempt);
        $provider->status = PaymentStatus::Confirmed;
        $quarantined = $service->reconcile($attempt);
        $this->assertSame(PaymentStatus::Confirmed, $quarantined->status);
        $this->assertTrue($quarantined->reconciliation_required);
        try {
            DB::transaction(fn () => app(OrderSettlementService::class)->finalize($order, $quarantined));
            $this->fail('Shared finalizer accepted quarantined funds.');
        } catch (ConflictHttpException) {
            $this->assertSame('pending_payment', $order->fresh()->status->value);
            $this->assertNull($order->fresh()->accepted_payment_id);
            $this->assertSame('18.0000', $stock->fresh()->reserved);
            $this->assertSame('100.0000', $stock->fresh()->on_hand);
            $this->assertSame(0, DB::table('stock_movements')->where('reason', 'sale')->count());
            $this->assertDatabaseCount('payment_evidence', 1);
        }
    }

    public function test_mismatched_first_funds_then_different_matching_transaction_stays_quarantined_with_both_observations(): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $order = $this->tracked($actor, $product);
        $provider = new FakePaymentProvider;
        $this->app->instance(PaymentProvider::class, $provider);
        $service = app(ExternalPaymentService::class);
        $attempt = $service->initiate($actor, $order, 'quarantined-second-key');
        $provider->facts = ['amount' => 326, 'transaction' => 'SYNTHETIC-FIRST-MISMATCH'];
        $this->assertTrue($service->reconcile($attempt)->reconciliation_required);
        $provider->facts = ['transaction' => 'SYNTHETIC-SECOND-MATCH'];
        $result = $service->reconcile($attempt);
        $this->assertSame(PaymentStatus::Confirmed, $result->status);
        $this->assertTrue($result->reconciliation_required);
        $this->assertDatabaseCount('payment_evidence', 2);
        $this->assertSame('pending_payment', $order->fresh()->status->value);
        $this->assertNull($order->fresh()->accepted_payment_id);
        $this->assertSame('18.0000', $stock->fresh()->reserved);
        $this->assertSame('100.0000', $stock->fresh()->on_hand);
        $this->assertSame(0, DB::table('stock_movements')->where('reason', 'sale')->count());
    }
}
