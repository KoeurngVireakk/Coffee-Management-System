<?php

use App\Models\Order;
use App\Models\Payment;
use App\Models\User;
use App\Payments\PaymentProvider;
use App\Services\CashPaymentService;
use App\Services\ExternalPaymentService;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Tests\Support\FakePaymentProvider;

require dirname(__DIR__, 2).'/vendor/autoload.php';

try {
    $payload = json_decode(fgets(STDIN), true, flags: JSON_THROW_ON_ERROR);
    $connection = $payload['connection'];
    if ($connection['driver'] !== 'mysql' || $connection['database'] !== 'coffee_management_auth_test'
        || ! in_array($connection['host'], ['127.0.0.1', 'localhost'], true) || ! empty($connection['url']) || ! empty($connection['unix_socket'])) {
        throw new RuntimeException('Unsafe payment worker target.');
    }
    putenv('APP_ENV=testing');
    $_ENV['APP_ENV'] = $_SERVER['APP_ENV'] = 'testing';
    $app = require dirname(__DIR__, 2).'/bootstrap/app.php';
    $app->make(Kernel::class)->bootstrap();
    config(['database.default' => 'mysql', 'database.connections.mysql' => $connection, 'cache.default' => 'array', 'app.debug' => false]);
    Http::preventStrayRequests();
    if (DB::selectOne('SELECT @@datadir AS directory')->directory !== $payload['datadir']) {
        throw new RuntimeException('Unexpected worker instance.');
    }
    $fake = new FakePaymentProvider;
    $fake->facts = $payload['facts'] ?? [];
    $app->instance(PaymentProvider::class, $fake);
    $id = DB::selectOne('SELECT CONNECTION_ID() AS id')->id;
    $pause = function (string $label) use ($id): void {
        echo $label.' '.$id.PHP_EOL;
        flush();
        if (trim(fgets(STDIN)) !== 'GO') {
            throw new RuntimeException('Closed worker barrier.');
        }
    };
    $ready = false;
    $held = false;
    DB::connection()->beforeExecuting(function (string $sql) use ($payload, $pause, &$ready): void {
        if (! $ready && ($payload['barrier'] ?? '') === 'before-order-lock' && str_starts_with($sql, 'select * from `orders`') && str_contains($sql, 'for update')) {
            $ready = true;
            $pause('READY');
        }
    });
    DB::listen(function ($event) use ($payload, $pause, &$ready, &$held): void {
        if (! $ready && ($payload['barrier'] ?? '') === 'after-evidence-read' && str_starts_with($event->sql, 'select * from `payment_evidence`')) {
            $ready = true;
            $pause('READY');
        }
        $orderLock = ($payload['hold'] ?? '') === 'order' && str_starts_with($event->sql, 'select * from `orders`') && str_contains($event->sql, 'for update');
        $evidenceLock = ($payload['hold'] ?? '') === 'evidence' && str_starts_with($event->sql, 'insert into `payment_evidence`');
        if (! $held && ($orderLock || $evidenceLock)) {
            $held = true;
            $pause('LOCKED');
        }
    });
    if ($payload['mode'] === 'verify') {
        $payment = $app->make(ExternalPaymentService::class)->reconcile(Payment::findOrFail($payload['payment_id']));
        $status = 200;
    } else {
        $actor = User::query()->with('role')->findOrFail($payload['actor_id']);
        $order = Order::findOrFail($payload['order_id']);
        $payment = $payload['mode'] === 'cash'
            ? $app->make(CashPaymentService::class)->settle($actor, $order, $payload['tender'], $payload['key'])
            : $app->make(ExternalPaymentService::class)->initiate($actor, $order, $payload['key']);
        $status = $payment->wasRecentlyCreated ? 201 : 200;
    }
    $result = ['status' => $status, 'payment_id' => $payment->id, 'payment_status' => $payment->status->value,
        'reconciliation_required' => $payment->reconciliation_required];
} catch (HttpExceptionInterface $exception) {
    $result = ['status' => $exception->getStatusCode()];
} catch (Throwable $exception) {
    fwrite(STDERR, 'Payment worker failure: '.$exception::class.PHP_EOL);
    exit(1);
}
echo json_encode($result, JSON_THROW_ON_ERROR).PHP_EOL;
