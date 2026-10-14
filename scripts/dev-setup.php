<?php

declare(strict_types=1);
use Illuminate\Database\QueryException;

// Secrets arrive through stdin, never command-line arguments or temporary payload files.
ini_set('display_errors', '0');
ini_set('log_errors', '0');
$input = [];
$environment = [];
try {
    $backend = $argv[2] ?? dirname(__DIR__).'/apps/backend';
    require $backend.'/vendor/autoload.php';
    require __DIR__.'/lib/dev-setup.php';
    $input = json_decode(stream_get_contents(STDIN), true, 512, JSON_THROW_ON_ERROR) ?? [];
    $setup = new DevSetup($backend);
    // Capture secrets before actions so driver errors can be redacted too.
    $environment = $setup->environment();
    $result = match ($argv[1] ?? '') {
        'inspect' => $setup->inspect(),
        'configure' => $setup->configure($input),
        'database' => $setup->database(),
        'create-database' => $setup->database(true, $input),
        'admin-status' => $setup->adminStatus(),
        'create-admin' => $setup->createAdmin($input),
        'ready' => $setup->ready(),
        default => throw new RuntimeException('Unknown setup action.'),
    };
    echo json_encode(['ok' => true, 'result' => $result], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE), PHP_EOL;
} catch (Throwable $error) {
    // Laravel query errors include bound SQL values. Show the driver's underlying error instead.
    if ($error instanceof QueryException && $error->getPrevious() instanceof PDOException) {
        $error = $error->getPrevious();
    }
    $message = $error->getMessage();
    foreach ([$input['DB_PASSWORD'] ?? '', $input['password'] ?? '', $environment['DB_PASSWORD'] ?? '', $environment['APP_KEY'] ?? ''] as $secret) {
        if ($secret !== '') {
            $message = str_replace($secret, '[redacted]', $message);
        }
    }
    $code = $error instanceof PDOException ? ($error->errorInfo[1] ?? null) : null;
    $fix = match ($code) {
        1045 => 'Check the MySQL username/password and host grants. Rerun .\setup.ps1 -ConfigureDatabase.',
        1044, 1142, 1227 => 'Grant this development account access to its database. See docs/database/README.md; do not weaken production grants.',
        2002, 2003 => 'Start your local MySQL service and check DB_HOST/DB_PORT. Use Services (services.msc) or your MySQL/Docker controls.',
        default => 'Correct the reported problem, then rerun setup.ps1. Existing data and passwords are not reset.',
    };
    echo json_encode(['ok' => false, 'error' => $message, 'driverCode' => $code, 'fix' => $fix], JSON_INVALID_UTF8_SUBSTITUTE), PHP_EOL;
    exit(1);
}
