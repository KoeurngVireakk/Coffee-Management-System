<?php

namespace Tests\Feature;

use App\Enums\PaymentStatus;
use App\Enums\StaffRole;
use App\Models\User;
use App\Payments\PaymentProvider;
use App\Services\ExternalPaymentService;
use App\Services\InventoryConsistencyService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Symfony\Component\Process\InputStream;
use Symfony\Component\Process\Process;
use Tests\Support\FakePaymentProvider;
use Tests\Support\InventoryFixtures;
use Tests\TestCase;

class InventoryConcurrencyTest extends TestCase
{
    use DatabaseMigrations, InventoryFixtures;

    private array $workers = [];

    protected function beforeRefreshingDatabase(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('Inventory concurrency requires real independent MySQL connections.');
        }
    }

    protected function tearDown(): void
    {
        foreach ($this->workers as [$process, $input]) {
            $input->close();
            if ($process->isRunning()) {
                $process->stop(0);
            }
        }
        parent::tearDown();
    }

    private function worker(array $payload): array
    {
        $payload += ['connection' => DB::connection()->getConfig(), 'datadir' => DB::selectOne('SELECT @@datadir AS directory')->directory];
        $input = new InputStream;
        $input->write(json_encode($payload, JSON_THROW_ON_ERROR)."\n");
        $process = new Process([PHP_BINARY, base_path('tests/Support/inventory-worker.php')], base_path(), input: $input, timeout: 20);
        $process->start();
        $this->workers[] = [$process, $input];

        return [$process, $input];
    }

    private function barrier(array $worker, string $label): int
    {
        $deadline = microtime(true) + 10;
        while (! preg_match('/'.$label.' (\d+)/', $worker[0]->getOutput(), $match)) {
            if (! $worker[0]->isRunning() || microtime(true) >= $deadline) {
                $this->fail('Worker barrier failure: '.$worker[0]->getErrorOutput());
            }
            usleep(10000);
        }

        return (int) $match[1];
    }

    private function release(array $worker, bool $close = true): void
    {
        $worker[1]->write("GO\n");
        if ($close) {
            $worker[1]->close();
        }
        $worker[0]->isRunning();
    }

    private function blocked(array $worker, int $connectionId): void
    {
        $deadline = microtime(true) + 5;
        do {
            $worker[0]->isRunning();
            $waiting = DB::selectOne('SELECT COUNT(*) AS count FROM performance_schema.data_lock_waits w JOIN performance_schema.threads t ON w.REQUESTING_THREAD_ID=t.THREAD_ID WHERE t.PROCESSLIST_ID=?', [$connectionId])->count;
            if ($waiting) {
                $this->assertGreaterThan(0, $waiting);

                return;
            }
            usleep(10000);
        } while (microtime(true) < $deadline);
        $this->fail('Expected an observable inventory-related InnoDB lock wait.');
    }

    private function outcome(array $worker): array
    {
        $worker[0]->wait();
        $this->assertTrue($worker[0]->isSuccessful(), $worker[0]->getErrorOutput());
        $lines = preg_split('/\r?\n/', trim($worker[0]->getOutput()));

        return json_decode(end($lines), true, flags: JSON_THROW_ON_ERROR);
    }

    private function race(array $firstPayload, array $secondPayload): array
    {
        $first = $this->worker($firstPayload);
        $second = $this->worker($secondPayload);
        $this->barrier($first, 'READY');
        $secondId = $this->barrier($second, 'READY');
        $this->release($first, false);
        $this->barrier($first, 'LOCKED');
        $this->release($second);
        $this->blocked($second, $secondId);
        $this->release($first);

        return [$this->outcome($first), $this->outcome($second)];
    }

    private function consistent(): void
    {
        $report = app(InventoryConsistencyService::class)->audit();
        $this->assertSame(0, $report['finding_count'], json_encode($report['findings']));
    }

    public function test_two_checkouts_competing_for_last_stock_only_reserve_one_order(): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory('18.0000');
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $base = ['actor_id' => $actor->id, 'mode' => 'checkout', 'items' => [['product_id' => $product->id, 'quantity' => 1]]];
        [$one, $two] = $this->race([...$base, 'key' => 'last-stock-first', 'hold' => 'inventory_items'], [...$base, 'key' => 'last-stock-second']);
        $this->assertSame([201, 422], [$one['status'], $two['status']]);
        $this->assertDatabaseCount('orders', 1);
        $this->assertDatabaseCount('stock_reservations', 1);
        $this->assertSame('18.0000', $stock->fresh()->reserved);
        $this->consistent();
    }

    public static function checkoutAdjustmentOrder(): array
    {
        return ['checkout first' => [true], 'negative adjustment first' => [false]];
    }

    #[DataProvider('checkoutAdjustmentOrder')]
    public function test_checkout_and_negative_adjustment_cannot_spend_the_same_available_stock(bool $checkoutFirst): void
    {
        $actor = User::factory()->withRole(StaffRole::Manager)->create();
        $stock = $this->inventory('18.0000');
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $checkout = ['actor_id' => $actor->id, 'mode' => 'checkout', 'items' => [['product_id' => $product->id, 'quantity' => 1]], 'key' => 'checkout-adjust-race'];
        $movement = ['actor_id' => $actor->id, 'mode' => 'movement', 'inventory_item_id' => $stock->id, 'key' => 'negative-adjust-race',
            'movement' => ['reason' => 'adjustment', 'quantity_delta' => '-18.0000', 'note' => 'Synthetic correction']];
        [$one, $two] = $this->race([...($checkoutFirst ? $checkout : $movement), 'hold' => 'inventory_items'], $checkoutFirst ? $movement : $checkout);
        $this->assertSame(201, $one['status']);
        $this->assertContains($two['status'], [409, 422]);
        $this->assertSame($checkoutFirst ? '18.0000' : '0.0000', $stock->fresh()->on_hand);
        $this->assertSame($checkoutFirst ? '18.0000' : '0.0000', $stock->fresh()->reserved);
        $this->consistent();
    }

    public function test_two_manual_adjustments_preserve_both_increments_without_lost_update(): void
    {
        $actor = User::factory()->withRole(StaffRole::Manager)->create();
        $stock = $this->inventory();
        $base = ['actor_id' => $actor->id, 'mode' => 'movement', 'inventory_item_id' => $stock->id,
            'movement' => ['reason' => 'adjustment', 'quantity_delta' => '0.1234', 'note' => 'Synthetic count correction']];
        [$one, $two] = $this->race([...$base, 'key' => 'adjustment-race-one', 'hold' => 'inventory_items'], [...$base, 'key' => 'adjustment-race-two']);
        $this->assertSame([201, 201], [$one['status'], $two['status']]);
        $this->assertSame('100.2468', $stock->fresh()->on_hand);
        $this->assertDatabaseCount('stock_movements', 3);
        $this->consistent();
    }

    public function test_checkout_shared_product_lock_preserves_complete_recipe_while_replacement_waits(): void
    {
        $actor = User::factory()->withRole(StaffRole::Manager)->create();
        $one = $this->inventory();
        $two = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $one->id, 'quantity' => '1.0000'], ['inventory_item_id' => $two->id, 'quantity' => '2.0000']]);
        $checkout = ['actor_id' => $actor->id, 'mode' => 'checkout', 'items' => [['product_id' => $product->id, 'quantity' => 1]], 'key' => 'recipe-snapshot-race', 'hold' => 'products'];
        $replacement = ['actor_id' => $actor->id, 'mode' => 'recipe', 'product_id' => $product->id,
            'ingredients' => [['inventory_item_id' => $one->id, 'quantity' => '3.0000'], ['inventory_item_id' => $two->id, 'quantity' => '4.0000']]];
        [$first, $second] = $this->race($checkout, $replacement);
        $this->assertSame([201, 200], [$first['status'], $second['status']]);
        $this->assertSame('1.0000', $one->fresh()->reserved);
        $this->assertSame('2.0000', $two->fresh()->reserved);
        $this->tracked($actor, $product, 'new-recipe-after-race');
        $this->assertSame('4.0000', $one->fresh()->reserved);
        $this->assertSame('6.0000', $two->fresh()->reserved);
        $this->consistent();
    }

    public static function movementKeyTargets(): array
    {
        return ['same item retry' => [true], 'different item conflicts' => [false]];
    }

    #[DataProvider('movementKeyTargets')]
    public function test_same_actor_movement_key_replay_or_unique_identity_conflict_never_duplicates_stock(bool $sameItem): void
    {
        $actor = User::factory()->withRole(StaffRole::Manager)->create();
        $one = $this->inventory();
        $two = $sameItem ? $one : $this->inventory();
        $base = ['actor_id' => $actor->id, 'mode' => 'movement', 'key' => 'one-global-movement-key',
            'movement' => ['reason' => 'receipt', 'quantity_delta' => '1.0000', 'note' => 'Synthetic delivery']];
        [$first, $second] = $this->race([...$base, 'inventory_item_id' => $one->id, 'hold' => $sameItem ? 'inventory_items' : 'stock_movements'],
            [...$base, 'inventory_item_id' => $two->id]);
        $this->assertSame([201, $sameItem ? 200 : 409], [$first['status'], $second['status']]);
        $this->assertSame('101.0000', $one->fresh()->on_hand);
        $this->assertSame($sameItem ? '101.0000' : '100.0000', $two->fresh()->on_hand);
        $this->assertSame(1, DB::table('stock_movements')->where('reason', 'receipt')->count());
        $this->consistent();
    }

    public static function terminalRaces(): array
    {
        return ['cash vs cancel' => ['cash', 'cancel', false], 'cancel vs cash' => ['cancel', 'cash', false],
            'external confirmation vs cancel' => ['verify', 'cancel', false], 'cancel vs late external confirmation' => ['cancel', 'verify', true],
            'duplicate cash key' => ['cash', 'cash', true], 'duplicate verified result' => ['verify', 'verify', true],
            'two different payments' => ['cash', 'cash', false]];
    }

    #[DataProvider('terminalRaces')]
    public function test_order_lock_protects_terminal_outcome_and_exactly_once_consumption(string $firstMode, string $secondMode, bool $sameKey): void
    {
        $actor = User::factory()->create();
        $stock = $this->inventory();
        $product = $this->recipe([['inventory_item_id' => $stock->id, 'quantity' => '18.0000']]);
        $order = $this->tracked($actor, $product);
        $base = ['actor_id' => $actor->id, 'order_id' => $order->id, 'tender' => 325];
        if ($firstMode === 'verify' || $secondMode === 'verify') {
            $provider = new FakePaymentProvider;
            $this->app->instance(PaymentProvider::class, $provider);
            $attempt = app(ExternalPaymentService::class)->initiate($actor, $order, 'terminal-external-key');
            $base['payment_id'] = $attempt->id;
            if ($firstMode === 'cancel') {
                $provider->status = PaymentStatus::Failed;
                app(ExternalPaymentService::class)->reconcile($attempt);
            }
        }
        [$first, $second] = $this->race([...$base, 'mode' => $firstMode, 'key' => 'terminal-payment-one', 'hold' => 'orders'],
            [...$base, 'mode' => $secondMode, 'key' => $sameKey ? 'terminal-payment-one' : 'terminal-payment-two']);
        $this->assertSame($firstMode === 'cash' ? 201 : 200, $first['status']);
        $expectedSecond = $secondMode === 'verify' || ($sameKey && $firstMode === $secondMode) ? 200 : 409;
        $this->assertSame($expectedSecond, $second['status']);
        $cancelled = $firstMode === 'cancel';
        $this->assertSame($cancelled ? 'cancelled' : 'paid', $order->fresh()->status->value);
        $this->assertSame($cancelled ? '100.0000' : '82.0000', $stock->fresh()->on_hand);
        $this->assertSame('0.0000', $stock->fresh()->reserved);
        $this->assertSame($cancelled ? 0 : 1, DB::table('stock_movements')->where('reason', 'sale')->count());
        $this->assertDatabaseHas('stock_reservations', ['order_id' => $order->id, 'status' => $cancelled ? 'released' : 'consumed']);
        if ($cancelled && $secondMode === 'verify') {
            $this->assertTrue($second['reconciliation_required']);
        }
        $this->consistent();
    }
}
