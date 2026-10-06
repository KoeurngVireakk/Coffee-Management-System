<?php

use App\Models\User;
use App\Services\StaffManagementService;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

require dirname(__DIR__, 2).'/vendor/autoload.php';

try {
    $payload = json_decode(fgets(STDIN), true, flags: JSON_THROW_ON_ERROR);
    $connection = $payload['connection'];
    if ($connection['driver'] !== 'mysql' || ! in_array($connection['database'], ['coffee_management_auth_test', 'coffee_management_staff_upgrade_test'], true)
        || ! in_array($connection['host'], ['127.0.0.1', 'localhost'], true) || ! empty($connection['url']) || ! empty($connection['unix_socket'])) {
        throw new RuntimeException('Unsafe worker database.');
    }

    putenv('APP_ENV=testing');
    $_ENV['APP_ENV'] = $_SERVER['APP_ENV'] = 'testing';
    $app = require dirname(__DIR__, 2).'/bootstrap/app.php';
    $app->make(Kernel::class)->bootstrap();

    config([
        'app.debug' => false,
        'database.default' => 'mysql',
        'database.connections.mysql' => $connection,
        'cache.default' => 'array',
    ]);

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

    if (! empty($payload['barrier']) && $payload['barrier'] === 'start') {
        $pause();
    }

    $staffService = $app->make(StaffManagementService::class);
    $admin = User::findOrFail($payload['admin_id']);

    if ($payload['action'] === 'deactivate') {
        $target = User::findOrFail($payload['target_id']);
        $result = $staffService->updateStaff($admin, $target, ['is_active' => false]);
        echo json_encode([
            'status' => 'success',
            'user_id' => $result->id,
            'is_active' => $result->is_active,
        ]).PHP_EOL;
    } elseif ($payload['action'] === 'demote') {
        $target = User::findOrFail($payload['target_id']);
        $result = $staffService->updateStaff($admin, $target, ['role' => 'cashier']);
        echo json_encode([
            'status' => 'success',
            'user_id' => $result->id,
            'role' => $result->role->name,
        ]).PHP_EOL;
    } elseif ($payload['action'] === 'create') {
        $result = $staffService->createStaff($admin, [
            'name' => $payload['name'],
            'email' => $payload['email'],
            'role' => $payload['role'],
            'password' => 'Valid-passphrase!2026',
        ]);
        echo json_encode([
            'status' => 'success',
            'user_id' => $result->id,
            'email' => $result->email,
        ]).PHP_EOL;
    }
} catch (HttpExceptionInterface $e) {
    echo json_encode([
        'status' => 'error',
        'http_status' => $e->getStatusCode(),
        'message' => $e->getMessage(),
    ]).PHP_EOL;
} catch (Throwable $e) {
    echo json_encode([
        'status' => 'error',
        'type' => get_class($e),
        'message' => $e->getMessage(),
    ]).PHP_EOL;
}
