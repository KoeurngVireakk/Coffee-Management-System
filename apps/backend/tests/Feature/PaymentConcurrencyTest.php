<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\Payment;
use App\Models\User;
use App\Payments\PaymentProvider;
use App\Services\ExternalPaymentService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\DataProvider;
use Symfony\Component\Process\InputStream;
use Symfony\Component\Process\Process;
use Tests\Support\FakePaymentProvider;
use Tests\TestCase;

class PaymentConcurrencyTest extends TestCase
{
    use DatabaseMigrations;

    private array $workers = [];

    protected function beforeRefreshingDatabase(): void
    {
        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('Payment lock/identity races require independent MySQL connections.');
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
        $process = new Process([PHP_BINARY, base_path('tests/Support/payment-worker.php')], base_path(), input: $input, timeout: 15);
        $process->start();
        $this->workers[] = [$process, $input];

        return [$process, $input];
    }

    private function waitLabel(array $worker, string $label): int
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

    private function observeWait(array $worker, int $connectionId): void
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
        $this->fail('Expected an observable payment-related InnoDB wait.');
    }

    private function outcome(array $worker): array
    {
        $worker[0]->wait();
        $this->assertTrue($worker[0]->isSuccessful(), $worker[0]->getErrorOutput());
        $lines = preg_split('/\r?\n/', trim($worker[0]->getOutput()));

        return json_decode(end($lines), true, flags: JSON_THROW_ON_ERROR);
    }

    public static function modes(): array
    {
        return ['same cash key' => ['cash', 'cash', true], 'different cash keys' => ['cash', 'cash', false],
            'cash first vs external' => ['cash', 'external', false], 'external first vs cash' => ['external', 'cash', false],
            'two external attempts' => ['external', 'external', false]];
    }

    #[DataProvider('modes')]
    public function test_one_order_lock_serializes_cash_and_external_attempt_races(string $firstMode, string $secondMode, bool $sameKey): void
    {
        $actor = User::factory()->create();
        $order = Order::factory()->create(['created_by' => $actor->id]);
        $base = ['actor_id' => $actor->id, 'order_id' => $order->id, 'tender' => 500, 'barrier' => 'before-order-lock'];
        $first = $this->worker([...$base, 'mode' => $firstMode, 'key' => 'first-payment-key', 'hold' => 'order']);
        $second = $this->worker([...$base, 'mode' => $secondMode, 'key' => $sameKey ? 'first-payment-key' : 'second-payment-key']);
        $this->waitLabel($first, 'READY');
        $secondId = $this->waitLabel($second, 'READY');
        $this->release($first, false);
        $this->waitLabel($first, 'LOCKED');
        $this->release($second);
        $this->observeWait($second, $secondId);
        $this->release($first);
        $one = $this->outcome($first);
        $two = $this->outcome($second);
        $this->assertSame(201, $one['status']);
        $this->assertSame($sameKey ? 200 : 409, $two['status']);
        $this->assertDatabaseCount('payments', 1);
        if ($firstMode === 'external') {
            $this->app->instance(PaymentProvider::class, new FakePaymentProvider);
            app(ExternalPaymentService::class)->reconcile(Payment::query()->sole());
        }
        $this->assertSame('paid', $order->fresh()->status->value);
        $this->assertSame($one['payment_id'], $order->fresh()->accepted_payment_id);
    }

    public function test_duplicate_provider_identity_race_can_only_credit_one_order(): void
    {
        $actor = User::factory()->create();
        $fake = new FakePaymentProvider;
        $this->app->instance(PaymentProvider::class, $fake);
        $service = app(ExternalPaymentService::class);
        $orders = Order::factory()->count(2)->create(['created_by' => $actor->id]);
        $payments = [];
        foreach ($orders as $order) {
            $payments[] = $service->initiate($actor, $order, 'external-race-key')->id;
        }
        $base = ['mode' => 'verify', 'facts' => ['transaction' => 'ONE-GLOBAL-PROVIDER-TX'], 'barrier' => 'after-evidence-read'];
        $first = $this->worker([...$base, 'payment_id' => $payments[0], 'hold' => 'evidence']);
        $second = $this->worker([...$base, 'payment_id' => $payments[1]]);
        $this->waitLabel($first, 'READY');
        $id = $this->waitLabel($second, 'READY');
        $this->release($first, false);
        $this->waitLabel($first, 'LOCKED');
        $this->release($second);
        $this->observeWait($second, $id);
        $this->release($first);
        $this->assertFalse($this->outcome($first)['reconciliation_required']);
        $this->assertTrue($this->outcome($second)['reconciliation_required']);
        $this->assertSame(1, Order::query()->where('status', 'paid')->count());
        $this->assertSame(1, Order::query()->whereNotNull('accepted_payment_id')->count());
        $this->assertDatabaseCount('payment_evidence', 1);
    }
}
