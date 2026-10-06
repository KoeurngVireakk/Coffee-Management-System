<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Services\OrderCheckoutService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Symfony\Component\Process\InputStream;
use Symfony\Component\Process\Process;
use Tests\TestCase;

class OrderConcurrencyTest extends TestCase
{
    use DatabaseMigrations;

    private array $workers = [];

    // Skip before DatabaseMigrations runs on SQLite; safety guard runs first in TestCase.
    protected function beforeRefreshingDatabase(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('Real independent-connection lock/race tests require MySQL.');
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
        if (isset($this->app) && DB::transactionLevel()) {
            DB::rollBack();
        }
        parent::tearDown();
    }

    private function worker(array $payload): array
    {
        $input = new InputStream;
        $payload += ['connection' => DB::connection()->getConfig(), 'datadir' => DB::selectOne('SELECT @@datadir AS directory')->directory];
        $input->write(json_encode($payload, JSON_THROW_ON_ERROR)."\n");
        $process = new Process([PHP_BINARY, base_path('tests/Support/order-worker.php')], base_path(), input: $input, timeout: 15);
        $process->start();
        $worker = [$process, $input];
        $this->workers[] = $worker;

        return $worker;
    }

    private function ready(array $worker): int
    {
        [$process] = $worker;
        $deadline = microtime(true) + 10;
        while (! preg_match('/READY (\d+)/', $process->getOutput(), $match)) {
            if (! $process->isRunning() || microtime(true) >= $deadline) {
                $this->fail('Worker did not reach barrier: '.$process->getErrorOutput());
            }
            usleep(10000);
        }

        return (int) $match[1];
    }

    private function release(array $worker): void
    {
        $worker[1]->write("GO\n");
        $worker[1]->close();
    }

    private function workerResult(array $worker): array
    {
        [$process] = $worker;
        $process->wait();
        $this->assertTrue($process->isSuccessful(), $process->getErrorOutput());
        $lines = preg_split('/\r?\n/', trim($process->getOutput()));

        return json_decode(end($lines), true, flags: JSON_THROW_ON_ERROR);
    }

    private function blocked(int $connectionId, array $worker): void
    {
        $deadline = microtime(true) + 5;
        do {
            // Symfony pumps asynchronous stdin when process status/output is polled.
            $worker[0]->isRunning();
            $waiting = DB::selectOne('SELECT COUNT(*) AS count FROM performance_schema.data_lock_waits w JOIN performance_schema.threads t ON w.REQUESTING_THREAD_ID = t.THREAD_ID WHERE t.PROCESSLIST_ID = ?', [$connectionId])->count;
            if ($waiting) {
                $this->assertGreaterThan(0, $waiting);

                return;
            }
            usleep(10000);
        } while (microtime(true) < $deadline);
        $this->fail('Expected an observable InnoDB row-lock wait.');
    }

    public static function simultaneousIntents(): array
    {
        return ['same semantic cart' => [false], 'conflicting cart' => [true]];
    }

    #[DataProvider('simultaneousIntents')]
    public function test_concurrent_same_actor_key_has_one_winner_and_comparison_after_unique_race(bool $conflict): void
    {
        $actor = User::factory()->create();
        $product = Product::factory()->create(['price_minor' => 325]);
        $base = ['actor_id' => $actor->id, 'key' => 'concurrent-same-key', 'barrier' => 'after-replay-check'];
        $first = $this->worker([...$base, 'items' => [['product_id' => $product->id, 'quantity' => 1]]]);
        $second = $this->worker([...$base, 'items' => [['product_id' => $product->id, 'quantity' => $conflict ? 2 : 1]]]);
        $this->ready($first);
        $this->ready($second);
        $this->release($first);
        $this->release($second);
        $results = [$this->workerResult($first), $this->workerResult($second)];
        $statuses = array_column($results, 'status');
        sort($statuses);
        $this->assertSame($conflict ? [201, 409] : [200, 201], $statuses);
        $this->assertSame([1, 1], array_column($results, 'insert_attempts'), 'Both independent transactions attempted insertion.');
        $reads = array_column($results, 'replay_reads');
        sort($reads);
        $this->assertSame([1, 2], $reads, 'Loser performs a fresh winner lookup after rollback.');
        $this->assertDatabaseCount('orders', 1);
        $this->assertDatabaseCount('order_items', 1);
        if (! $conflict) {
            $this->assertSame($results[0]['reference'], $results[1]['reference']);
        }
    }

    public static function catalogChanges(): array
    {
        return ['price change' => ['price'], 'product retirement' => ['product'], 'category retirement' => ['category']];
    }

    #[DataProvider('catalogChanges')]
    public function test_catalog_writer_first_blocks_checkout_until_latest_state_can_be_revalidated(string $change): void
    {
        $actor = User::factory()->create();
        $product = Product::factory()->create(['price_minor' => 325]);
        DB::beginTransaction();
        if ($change === 'category') {
            Category::query()->whereKey($product->category_id)->update(['is_active' => false]);
        } else {
            Product::query()->whereKey($product->id)->update($change === 'price' ? ['price_minor' => 700] : ['is_active' => false]);
        }
        $worker = $this->worker(['actor_id' => $actor->id, 'key' => 'catalog-writer-first',
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'barrier' => $change === 'category' ? 'before-category-read' : 'before-product-read']);
        $id = $this->ready($worker);
        $this->release($worker);
        $this->blocked($id, $worker);
        DB::commit();
        $result = $this->workerResult($worker);
        $this->assertSame($change === 'price' ? 201 : 422, $result['status']);
        if ($change === 'price') {
            $this->assertSame(700, Order::query()->sole()->items->sole()->unit_price_minor);
        } else {
            $this->assertDatabaseCount('orders', 0);
            $this->assertDatabaseCount('order_items', 0);
        }
    }

    public function test_checkout_shared_locks_hold_snapshot_while_later_price_writer_waits(): void
    {
        $actor = User::factory()->create();
        $product = Product::factory()->create(['price_minor' => 325]);
        $checkout = $this->worker(['actor_id' => $actor->id, 'key' => 'checkout-reader-first',
            'items' => [['product_id' => $product->id, 'quantity' => 1]], 'barrier' => 'after-category-read']);
        $this->ready($checkout);
        $writer = $this->worker(['mode' => 'write', 'table' => 'products', 'id' => $product->id,
            'changes' => ['price_minor' => 700], 'barrier' => 'before-write']);
        $id = $this->ready($writer);
        $this->release($writer);
        $this->blocked($id, $writer);
        $this->release($checkout);
        $this->assertSame(201, $this->workerResult($checkout)['status']);
        $this->assertSame(200, $this->workerResult($writer)['status']);
        $this->assertSame(325, Order::query()->sole()->items->sole()->unit_price_minor);
        $this->assertSame(700, $product->fresh()->price_minor);
    }

    public function test_unselected_catalog_rows_are_not_locked_by_checkout(): void
    {
        $actor = User::factory()->create();
        $product = Product::factory()->create();
        $unrelated = Product::factory()->create();
        $checkout = $this->worker(['actor_id' => $actor->id, 'key' => 'checkout-unrelated-row',
            'items' => [['product_id' => $product->id, 'quantity' => 1]], 'barrier' => 'after-category-read']);
        $this->ready($checkout);
        $writer = $this->worker(['mode' => 'write', 'table' => 'products', 'id' => $unrelated->id,
            'changes' => ['price_minor' => 700]]);
        $writer[1]->close();
        $this->assertSame(200, $this->workerResult($writer)['status']);
        $this->release($checkout);
        $this->assertSame(201, $this->workerResult($checkout)['status']);
    }

    public function test_replay_lookup_refreshes_after_catalog_validation_failure_when_winner_committed(): void
    {
        $actor = User::factory()->create();
        $product = Product::factory()->create(['price_minor' => 325]);
        $items = [['product_id' => $product->id, 'quantity' => 1]];
        $worker = $this->worker(['actor_id' => $actor->id, 'key' => 'winner-then-retirement',
            'items' => $items, 'barrier' => 'after-replay-check']);
        $this->ready($worker);
        $winner = app(OrderCheckoutService::class)->checkout($actor, $items, 'winner-then-retirement');
        $product->update(['is_active' => false]);
        $this->release($worker);
        $result = $this->workerResult($worker);
        $this->assertSame(200, $result['status']);
        $this->assertSame($winner->public_reference, $result['reference']);
        $this->assertSame(2, $result['replay_reads']);
        $this->assertDatabaseCount('orders', 1);
        $this->assertDatabaseCount('order_items', 1);
    }
}
