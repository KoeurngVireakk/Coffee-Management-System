<?php

// Reviewed test helper: independent process/connection; never migrates or resets a database.
use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use App\Services\OrderCheckoutService;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

require dirname(__DIR__, 2).'/vendor/autoload.php';

try {
    $payload = json_decode(fgets(STDIN), true, flags: JSON_THROW_ON_ERROR);
    $connection = $payload['connection'];
    if ($connection['driver'] !== 'mysql' || $connection['database'] !== 'coffee_management_auth_test'
        || ! in_array($connection['host'], ['127.0.0.1', 'localhost'], true) || ! empty($connection['url']) || ! empty($connection['unix_socket'])) {
        throw new RuntimeException('Unsafe worker database.');
    }
    putenv('APP_ENV=testing');
    $_ENV['APP_ENV'] = $_SERVER['APP_ENV'] = 'testing';
    $app = require dirname(__DIR__, 2).'/bootstrap/app.php';
    $app->make(Kernel::class)->bootstrap();
    config(['app.debug' => false, 'database.default' => 'mysql', 'database.connections.mysql' => $connection, 'cache.default' => 'array']);
    Http::preventStrayRequests();
    if (DB::selectOne('SELECT @@datadir AS directory')->directory !== $payload['datadir']) {
        throw new RuntimeException('Unexpected worker server.');
    }
    $connectionId = DB::selectOne('SELECT CONNECTION_ID() AS id')->id;
    $pause = function () use ($connectionId): void {
        echo 'READY '.$connectionId.PHP_EOL;
        flush();
        if (trim(fgets(STDIN)) !== 'GO') {
            throw new RuntimeException('Worker barrier closed.');
        }
    };
    $paused = false;
    $insertAttempts = 0;
    $replayReads = 0;
    DB::connection()->beforeExecuting(function (string $sql) use ($payload, $pause, &$paused, &$insertAttempts): void {
        if (str_starts_with($sql, 'insert into `orders`')) {
            $insertAttempts++;
        }
        $point = $payload['barrier'] ?? '';
        if (! $paused && (($point === 'before-product-read' && str_starts_with($sql, 'select * from `products`'))
            || ($point === 'before-category-read' && str_starts_with($sql, 'select * from `categories`'))
            || ($point === 'before-write' && str_starts_with($sql, 'update ')))) {
            $paused = true;
            $pause();
        }
    });
    DB::listen(function ($event) use ($payload, $pause, &$paused, &$replayReads): void {
        if (str_starts_with($event->sql, 'select * from `orders`') && str_contains($event->sql, 'checkout_key')) {
            $replayReads++;
            if (! $paused && ($payload['barrier'] ?? '') === 'after-replay-check') {
                $paused = true;
                $pause();
            }
        }
        if (! $paused && ($payload['barrier'] ?? '') === 'after-category-read' && str_starts_with($event->sql, 'select * from `categories`')) {
            $paused = true;
            $pause();
        }
    });

    if (($payload['mode'] ?? 'checkout') === 'write') {
        $model = $payload['table'] === 'products' ? Product::query()->findOrFail($payload['id']) : Category::query()->findOrFail($payload['id']);
        $model->update($payload['changes']);
        $result = ['status' => 200];
    } else {
        $actor = User::query()->with('role')->findOrFail($payload['actor_id']);
        $order = $app->make(OrderCheckoutService::class)->checkout($actor, $payload['items'], $payload['key']);
        $result = ['status' => $order->wasRecentlyCreated ? 201 : 200, 'reference' => $order->public_reference];
    }
} catch (ValidationException) {
    $result = ['status' => 422];
} catch (HttpExceptionInterface $exception) {
    $result = ['status' => $exception->getStatusCode()];
} catch (Throwable $exception) {
    fwrite(STDERR, 'Worker failure: '.$exception::class.PHP_EOL);
    exit(1);
}
echo json_encode([...$result, 'insert_attempts' => $insertAttempts, 'replay_reads' => $replayReads], JSON_THROW_ON_ERROR).PHP_EOL;
