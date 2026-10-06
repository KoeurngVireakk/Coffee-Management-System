<?php

// Synthetic independent-connection worker. Never migrates, repairs, or resets a database.
use App\Models\InventoryItem;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Product;
use App\Models\User;
use App\Payments\PaymentProvider;
use App\Services\CashPaymentService;
use App\Services\ExternalPaymentService;
use App\Services\OrderCancellationService;
use App\Services\OrderCheckoutService;
use App\Services\RecipeService;
use App\Services\StockMovementService;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Tests\Support\FakePaymentProvider;

require dirname(__DIR__, 2).'/vendor/autoload.php';

try {
    $payload = json_decode(fgets(STDIN), true, flags: JSON_THROW_ON_ERROR);
    $connection = $payload['connection'];
    if ($connection['driver'] !== 'mysql' || $connection['database'] !== 'coffee_management_auth_test'
        || ! in_array($connection['host'], ['127.0.0.1', 'localhost'], true) || ! empty($connection['url']) || ! empty($connection['unix_socket'])) {
        throw new RuntimeException('Unsafe inventory worker target.');
    }
    putenv('APP_ENV=testing');
    $_ENV['APP_ENV'] = $_SERVER['APP_ENV'] = 'testing';
    $app = require dirname(__DIR__, 2).'/bootstrap/app.php';
    $app->make(Kernel::class)->bootstrap();
    config(['database.default' => 'mysql', 'database.connections.mysql' => $connection, 'cache.default' => 'array',
        'app.debug' => false, 'inventory.tracking_enabled' => true]);
    Http::preventStrayRequests();
    if (DB::selectOne('SELECT @@datadir AS directory')->directory !== $payload['datadir']) {
        throw new RuntimeException('Unexpected worker instance.');
    }
    $app->instance(PaymentProvider::class, new FakePaymentProvider);
    $connectionId = DB::selectOne('SELECT CONNECTION_ID() AS id')->id;
    $pause = function (string $label) use ($connectionId): void {
        echo $label.' '.$connectionId.PHP_EOL;
        flush();
        if (trim(fgets(STDIN)) !== 'GO') {
            throw new RuntimeException('Closed inventory worker barrier.');
        }
    };
    $held = false;
    DB::listen(function ($event) use ($payload, $pause, &$held): void {
        $table = $payload['hold'] ?? null;
        $rowLock = $table !== null && str_starts_with($event->sql, 'select * from `'.$table.'`')
            && (str_contains($event->sql, 'for update') || str_contains($event->sql, 'lock in share mode'));
        $movementInsert = $table === 'stock_movements' && str_starts_with($event->sql, 'insert into `stock_movements`');
        if (! $held && ($rowLock || $movementInsert)) {
            $held = true;
            $pause('LOCKED');
        }
    });
    $actor = User::query()->with('role')->findOrFail($payload['actor_id']);
    $pause('READY');
    $model = match ($payload['mode']) {
        'checkout' => $app->make(OrderCheckoutService::class)->checkout($actor, $payload['items'], $payload['key']),
        'movement' => $app->make(StockMovementService::class)->append($actor, InventoryItem::findOrFail($payload['inventory_item_id']), $payload['movement'], $payload['key']),
        'recipe' => $app->make(RecipeService::class)->replace($actor, Product::findOrFail($payload['product_id']), $payload['ingredients']),
        'cash' => $app->make(CashPaymentService::class)->settle($actor, Order::findOrFail($payload['order_id']), $payload['tender'] ?? 325, $payload['key']),
        'verify' => $app->make(ExternalPaymentService::class)->reconcile(Payment::findOrFail($payload['payment_id'])),
        'cancel' => $app->make(OrderCancellationService::class)->cancel($actor, Order::findOrFail($payload['order_id'])),
    };
    $status = in_array($payload['mode'], ['cancel', 'recipe', 'verify'], true) ? 200 : ($model->wasRecentlyCreated ? 201 : 200);
    $result = ['status' => $status];
    if ($payload['mode'] === 'verify') {
        $result['reconciliation_required'] = $model->reconciliation_required;
    }
} catch (ValidationException) {
    $result = ['status' => 422];
} catch (HttpExceptionInterface $exception) {
    $result = ['status' => $exception->getStatusCode()];
} catch (Throwable $exception) {
    fwrite(STDERR, 'Inventory worker failure: '.$exception::class.PHP_EOL);
    exit(1);
}
echo json_encode($result, JSON_THROW_ON_ERROR).PHP_EOL;
